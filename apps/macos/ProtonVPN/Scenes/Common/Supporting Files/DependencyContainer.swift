//
//  DependencyContainer.swift
//  ProtonVPN - Created on 21/08/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import AppKit
import Foundation
import vpncore
import BugReport
import NetworkExtension
import Timer

// FUTURETODO: clean up objects that are possible to re-create if memory warning is received

final class DependencyContainer: Container {
    private let openVpnExtensionBundleIdentifier = "ch.protonvpn.mac.OpenVPN-Extension"
    private let wireguardVpnExtensionBundleIdentifier = "ch.protonvpn.mac.WireGuard-Extension"

    // Singletons
    private lazy var navigationService = NavigationService(self)
    private lazy var vpnManager: VpnManagerProtocol = VpnManager(ikeFactory: ikeFactory,
                                                                 openVpnFactory: openVpnFactory,
                                                                 wireguardProtocolFactory: wireguardFactory,
                                                                 appGroup: config.appGroup,
                                                                 vpnAuthentication: vpnAuthentication,
                                                                 vpnKeychain: makeVpnKeychain(),
                                                                 propertiesManager: makePropertiesManager(),
                                                                 vpnStateConfiguration: makeVpnStateConfiguration(),
                                                                 alertService: macAlertService,
                                                                 vpnCredentialsConfiguratorFactory: MacVpnCredentialsConfiguratorFactory(propertiesManager: makePropertiesManager()),
                                                                 localAgentConnectionFactory: LocalAgentConnectionFactoryImplementation(),
                                                                 natTypePropertyProvider: makeNATTypePropertyProvider(),
                                                                 netShieldPropertyProvider: makeNetShieldPropertyProvider(),
                                                                 safeModePropertyProvider: makeSafeModePropertyProvider())
    private lazy var ikeFactory = IkeProtocolFactory(factory: self)
    private lazy var wireguardFactory = WireguardMacProtocolFactory(bundleId: wireguardVpnExtensionBundleIdentifier,
                                                                    appGroup: config.appGroup,
                                                                    factory: self)
    private lazy var openVpnFactory = OpenVpnMacProtocolFactory(bundleId: openVpnExtensionBundleIdentifier,
                                                                appGroup: config.appGroup,
                                                                factory: self)
    private lazy var windowService: WindowService = WindowServiceImplementation(factory: self)
    private lazy var timerFactory: TimerFactory = TimerFactoryImplementation()
    private lazy var appStateManager: AppStateManager = AppStateManagerImplementation(
        vpnApiService: makeVpnApiService(),
        vpnManager: vpnManager,
        networking: makeNetworking(),
        alertService: macAlertService,
        timerFactory: timerFactory,
        propertiesManager: makePropertiesManager(),
        vpnKeychain: makeVpnKeychain(),
        configurationPreparer: makeVpnManagerConfigurationPreparer(),
        vpnAuthentication: vpnAuthentication,
        doh: makeDoHVPN(),
        serverStorage: makeServerStorage(),
        natTypePropertyProvider: makeNATTypePropertyProvider(),
        netShieldPropertyProvider: makeNetShieldPropertyProvider(),
        safeModePropertyProvider: makeSafeModePropertyProvider())
    private lazy var appSessionManager: AppSessionManagerImplementation = AppSessionManagerImplementation(factory: self)
    private lazy var macAlertService: MacAlertService = MacAlertService(factory: self)

    private lazy var xpcConnectionsRepository: XPCConnectionsRepository = XPCConnectionsRepositoryImplementation()

    private lazy var maintenanceManager: MaintenanceManagerProtocol = MaintenanceManager( factory: self )
    private lazy var maintenanceManagerHelper: MaintenanceManagerHelper = MaintenanceManagerHelper(factory: self)

    // Refreshes app data at predefined time intervals
    private lazy var refreshTimer = AppSessionRefreshTimer(factory: self,
                                                           timerFactory: timerFactory,
                                                           refreshIntervals: (AppConstants.Time.fullServerRefresh,
                                                                              AppConstants.Time.serverLoadsRefresh,
                                                                              AppConstants.Time.userAccountRefresh),
                                                           canRefreshLoads: { return NSApp.isActive })

    // Refreshes announcements from API
    private lazy var announcementRefresher = AnnouncementRefresherImplementation(factory: self)

    // Instance of DynamicBugReportManager is persisted because it has a timer that refreshes config from time to time.
    private lazy var dynamicBugReportManager = DynamicBugReportManager(
        api: makeReportsApiService(),
        storage: DynamicBugReportStorageUserDefaults(userDefaults: Storage()),
        alertService: makeCoreAlertService(),
        propertiesManager: makePropertiesManager(),
        updateChecker: makeUpdateManager(),
        vpnKeychain: makeVpnKeychain(),
        logContentProvider: makeLogContentProvider()
    )

    #if TLS_PIN_DISABLE
    private lazy var trustKitHelper: TrustKitHelper? = nil
    #else
    private lazy var trustKitHelper: TrustKitHelper? = TrustKitHelper()
    #endif

    // Manages app updates
    private lazy var updateManager = UpdateManager(self)
    private lazy var vpnAuthentication: VpnAuthentication = {
        return VpnAuthenticationManager(networking: makeNetworking(),
                                        storage: vpnAuthenticationKeychain,
                                        safeModePropertyProvider: makeSafeModePropertyProvider())
    }()
    private lazy var vpnAuthenticationKeychain = VpnAuthenticationKeychain(accessGroup: "\(config.appIdentifierPrefix)ch.protonvpn.macos", storage: storage)
    private lazy var appCertificateRefreshManager = AppCertificateRefreshManager(appSessionManager: makeAppSessionManager(), vpnAuthenticationStorage: vpnAuthenticationKeychain)

    private lazy var storage = Storage()
    private lazy var networkingDelegate: NetworkingDelegate = macOSNetworkingDelegate(alertService: macAlertService) // swiftlint:disable:this weak_delegate
    private lazy var networking = CoreNetworking(delegate: networkingDelegate, appInfo: makeAppInfo(), doh: makeDoHVPN(), authKeychain: makeAuthKeychainHandle())
    private lazy var planService = CorePlanService(networking: networking)
    private lazy var doh: DoHVPN = {
        let propertiesManager = makePropertiesManager()
        let doh = DoHVPN(alternativeRouting: propertiesManager.alternativeRouting,
                         customHost: propertiesManager.apiEndpoint)
        propertiesManager.onAlternativeRoutingChange = { alternativeRouting in
            doh.alternativeRouting = alternativeRouting
        }
        return doh
    }()
    private lazy var sysexManager = SystemExtensionManager(factory: self)

    public init() {
        let prefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String

        super.init(Config(appIdentifierPrefix: prefix,

                          appGroup: "\(prefix)group.ch.protonvpn.mac"))
    }

    // MARK: - Overridden factory & config methods
    override var modelId: String? {
        makeModelIdChecker().modelId
    }

    // MARK: DoHVPNFactory
    override func makeDoHVPN() -> DoHVPN {
        doh
    }

    // MARK: NetworkingDelegate
    override func makeNetworkingDelegate() -> NetworkingDelegate {
        networkingDelegate
    }
}

extension DoHVPN {
    convenience init(alternativeRouting: Bool, customHost: String?) {
        #if !RELEASE
        let atlasSecret: String? = ObfuscatedConstants.atlasSecret
        #else
        let atlasSecret: String? = nil
        #endif

        self.init(apiHost: ObfuscatedConstants.apiHost,
                  verifyHost: ObfuscatedConstants.humanVerificationV3Host,
                  alternativeRouting: alternativeRouting,
                  customHost: customHost,
                  atlasSecret: atlasSecret,
                  // Will get updated once AppStateManager is initialized
                  appState: .disconnected)
    }
}

// MARK: PlanServiceFactory
extension DependencyContainer: PlanServiceFactory {
    func makePlanService() -> PlanService {
        return planService
    }
}

// MARK: NavigationServiceFactory
extension DependencyContainer: NavigationServiceFactory {
    func makeNavigationService() -> NavigationService {
        return navigationService
    }
}

// MARK: VpnManagerFactory
extension DependencyContainer: VpnManagerFactory {
    func makeVpnManager() -> VpnManagerProtocol {
        return vpnManager
    }
}

// MARK: VpnManagerConfigurationPreparer
extension DependencyContainer: VpnManagerConfigurationPreparerFactory {
    func makeVpnManagerConfigurationPreparer() -> VpnManagerConfigurationPreparer {
        return VpnManagerConfigurationPreparer(vpnKeychain: makeVpnKeychain(), alertService: makeCoreAlertService(), propertiesManager: makePropertiesManager())
    }
}

// MARK: WindowServiceFactory
extension DependencyContainer: WindowServiceFactory {
    func makeWindowService() -> WindowService {
        return windowService
    }
}

// MARK: VpnApiServiceFactory
extension DependencyContainer: VpnApiServiceFactory {
    func makeVpnApiService() -> VpnApiService {
        return VpnApiService(networking: makeNetworking())
    }
}

// MARK: OsxUiAlertServiceFactory
extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        return OsxUiAlertService(factory: self)
    }
}

// MARK: CoreAlertServiceFactory
extension DependencyContainer: CoreAlertServiceFactory {
    func makeCoreAlertService() -> CoreAlertService {
        return macAlertService
    }
}

// MARK: AppStateManagerFactory
extension DependencyContainer: AppStateManagerFactory {
    func makeAppStateManager() -> AppStateManager {
        return appStateManager
    }
}

// MARK: AppSessionManagerFactory
extension DependencyContainer: AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager {
        return appSessionManager
    }
}

// MARK: VpnGatewayFactory
extension DependencyContainer: VpnGatewayFactory {
    func makeVpnGateway() -> VpnGatewayProtocol {
        let connectionIntercepts = ConnectionIntercepts(factory: self).intercepts

        return VpnGateway(vpnApiService: makeVpnApiService(),
                          appStateManager: makeAppStateManager(),
                          alertService: makeCoreAlertService(),
                          vpnKeychain: makeVpnKeychain(),
                          authKeychain: makeAuthKeychainHandle(),
                          siriHelper: SiriHelper(),
                          netShieldPropertyProvider: makeNetShieldPropertyProvider(),
                          natTypePropertyProvider: makeNATTypePropertyProvider(),
                          safeModePropertyProvider: makeSafeModePropertyProvider(),
                          propertiesManager: makePropertiesManager(),
                          profileManager: makeProfileManager(),
                          availabilityCheckerResolverFactory: self,
                          vpnInterceptPolicies: connectionIntercepts,
                          serverStorage: makeServerStorage())
    }
}

// MARK: NotificationManagerFactory
extension DependencyContainer: NotificationManagerFactory {
    func makeNotificationManager() -> NotificationManagerProtocol {
        return NotificationManager(appStateManager: makeAppStateManager(),
                                   appSessionManager: makeAppSessionManager())
    }
}

// MARK: ReportBugViewModelFactory
extension DependencyContainer: ReportBugViewModelFactory {
    func makeReportBugViewModel() -> ReportBugViewModel {
        return ReportBugViewModel(os: "MacOS",
                                  osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                                  propertiesManager: makePropertiesManager(),
                                  reportsApiService: makeReportsApiService(),
                                  alertService: makeCoreAlertService(),
                                  vpnKeychain: makeVpnKeychain(),
                                  logContentProvider: makeLogContentProvider(),
                                  authKeychain: makeAuthKeychainHandle())
    }
}

// MARK: ReportsApiServiceFactory
extension DependencyContainer: ReportsApiServiceFactory {
    func makeReportsApiService() -> ReportsApiService {
        return ReportsApiService(networking: makeNetworking(), authKeychain: makeAuthKeychainHandle())
    }
}

// MARK: TrustKitHelperFactory
extension DependencyContainer: TrustKitHelperFactory {
    func makeTrustKitHelper() -> TrustKitHelper? {
        return trustKitHelper
    }
}

// MARK: MigrationManagerFactory
extension DependencyContainer: MigrationManagerFactory {
    func makeMigrationManager() -> MigrationManagerProtocol {
        let propertiesManager = makePropertiesManager()
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return MigrationManager(propertiesManager, currentAppVersion: currentVersion)
    }
}

// MARK: - MaintenanceManagerFactory
extension DependencyContainer: MaintenanceManagerFactory {
    func makeMaintenanceManager() -> MaintenanceManagerProtocol {
        return maintenanceManager
    }
}

// MARK: RefreshTimerFactory
extension DependencyContainer: AppSessionRefreshTimerFactory {
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer {
        return refreshTimer
    }
}

// MARK: - AppSessionRefresherFactory
extension DependencyContainer: AppSessionRefresherFactory {
    func makeAppSessionRefresher() -> AppSessionRefresher {
        return appSessionManager
    }
}

// MARK: - MaintenanceManagerHelperFactory
extension DependencyContainer: MaintenanceManagerHelperFactory {
    func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper {
        return maintenanceManagerHelper
    }
}

// MARK: - AnnouncementRefresherFactory
extension DependencyContainer: AnnouncementRefresherFactory {
    func makeAnnouncementRefresher() -> AnnouncementRefresher {
        return announcementRefresher
    }
}

// MARK: - AnnouncementStorageFactory
extension DependencyContainer: AnnouncementStorageFactory {
    func makeAnnouncementStorage() -> AnnouncementStorage {
        return AnnouncementStorageUserDefaults(userDefaults: Storage.userDefaults(), keyNameProvider: nil)
    }
}

// MARK: - AnnouncementManagerFactory
extension DependencyContainer: AnnouncementManagerFactory {
    func makeAnnouncementManager() -> AnnouncementManager {
        return AnnouncementManagerImplementation(factory: self)
    }
}

// MARK: - CoreApiServiceFactory
extension DependencyContainer: CoreApiServiceFactory {
    func makeCoreApiService() -> CoreApiService {
        return CoreApiServiceImplementation(networking: makeNetworking())
    }
}

// MARK: - HeaderViewModelFactory
extension DependencyContainer: HeaderViewModelFactory {
    func makeHeaderViewModel() -> HeaderViewModel {
        return HeaderViewModel(factory: self, appStateManager: appStateManager, navService: navigationService)
    }
}

// MARK: - AnnouncementsViewModelFactory
extension DependencyContainer: AnnouncementsViewModelFactory {
    func makeAnnouncementsViewModel() -> AnnouncementsViewModel {
        return AnnouncementsViewModel(factory: self)
    }
}

// MARK: - SafariServiceFactory
extension DependencyContainer: SafariServiceFactory {
    func makeSafariService() -> SafariServiceProtocol {
        return SafariService()
    }
}

// MARK: - UserTierProviderFactory
extension DependencyContainer: UserTierProviderFactory {
    func makeUserTierProvider() -> UserTierProvider {
        return UserTierProviderImplementation(self)
    }
}

// MARK: - NetShieldPropertyProviderFactory
extension DependencyContainer: NetShieldPropertyProviderFactory {
    func makeNetShieldPropertyProvider() -> NetShieldPropertyProvider {
        return NetShieldPropertyProviderImplementation(self, storage: storage)
    }
}

// MARK: - UpdateFileSelectorFactory
extension DependencyContainer: UpdateFileSelectorFactory {
    func makeUpdateFileSelector() -> UpdateFileSelector {
        return UpdateFileSelectorImplementation(self)
    }
}

// MARK: - UpdateManagerFactory
extension DependencyContainer: UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager {
        return updateManager
    }
}

// MARK: - SystemExtensionManagerFactory
extension DependencyContainer: SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager {
        return sysexManager
    }
}

// MARK: - TroubleshootViewModelFactory
extension DependencyContainer: TroubleshootViewModelFactory {
    func makeTroubleshootViewModel() -> TroubleshootViewModel {
        return TroubleshootViewModel(propertiesManager: makePropertiesManager())
    }
}

// MARK: VpnAuthenticationManagerFactory
extension DependencyContainer: VpnAuthenticationFactory {
    func makeVpnAuthentication() -> VpnAuthentication {
        return vpnAuthentication
    }
}

// MARK: VpnStateConfigurationFactory
extension DependencyContainer: VpnStateConfigurationFactory {
    func makeVpnStateConfiguration() -> VpnStateConfiguration {
        return VpnStateConfigurationManager(ikeProtocolFactory: ikeFactory, openVpnProtocolFactory: openVpnFactory, wireguardProtocolFactory: wireguardFactory, propertiesManager: makePropertiesManager(), appGroup: config.appGroup)
    }
}

// MARK: XPCConnectionsRepositoryFactory
extension DependencyContainer: XPCConnectionsRepositoryFactory {
    func makeXPCConnectionsRepository() -> XPCConnectionsRepository {
        return xpcConnectionsRepository
    }
}

// MARK: LogFileManagerFactory
extension DependencyContainer: LogFileManagerFactory {
    func makeLogFileManager() -> LogFileManager {
        return LogFileManagerImplementation()
    }
}

// MARK: BugReportCreatorFactory
extension DependencyContainer: BugReportCreatorFactory {
    func makeBugReportCreator() -> BugReportCreator {
        return MacOSBugReportCreator()
    }
}

// MARK: DynamicBugReportManagerFactory
extension DependencyContainer: DynamicBugReportManagerFactory {
    func makeDynamicBugReportManager() -> DynamicBugReportManager {
        return dynamicBugReportManager
    }
}

// MARK: NATTypePropertyProviderFactory
extension DependencyContainer: NATTypePropertyProviderFactory {
    func makeNATTypePropertyProvider() -> NATTypePropertyProvider {
        return NATTypePropertyProviderImplementation(self, storage: storage)
    }
}

// MARK: SafeModePropertyProviderFactory
extension DependencyContainer: SafeModePropertyProviderFactory {
    func makeSafeModePropertyProvider() -> SafeModePropertyProvider {
        return SafeModePropertyProviderImplementation(self, storage: storage)
    }
}

// MARK: AppCertificateRefreshManagerFactory
extension DependencyContainer: AppCertificateRefreshManagerFactory {
    func makeAppCertificateRefreshManager() -> AppCertificateRefreshManager {
        return appCertificateRefreshManager
    }
}

// MARK: ModelIdCheckerFactory
extension DependencyContainer: ModelIdCheckerFactory {
    func makeModelIdChecker() -> ModelIdCheckerProtocol {
        return ModelIdChecker()
    }
}

// MARK: ProtonReachabilityCheckerFactory
extension DependencyContainer: ProtonReachabilityCheckerFactory {
    func makeProtonReachabilityChecker() -> ProtonReachabilityChecker {
        return URLSessionProtonReachabilityChecker()
    }
}

// MARK: PaymentsApiServiceFactory
extension DependencyContainer: PaymentsApiServiceFactory {
    func makePaymentsApiService() -> PaymentsApiService {
        return PaymentsApiServiceImplementation(networking: makeNetworking(), vpnKeychain: makeVpnKeychain(), vpnApiService: makeVpnApiService())
    }
}

// MARK: CouponViewModelFactory
extension DependencyContainer: CouponViewModelFactory {
    func makeCouponViewModel() -> CouponViewModel {
        return CouponViewModel(paymentsApiService: makePaymentsApiService(), appSessionRefresher: appSessionManager)
    }
}

// MARK: LogContentProviderFactory
extension DependencyContainer: LogContentProviderFactory {
    func makeLogContentProvider() -> LogContentProvider {
        return MacOSLogContentProvider(appLogsFolder: LogFileManagerImplementation().getFileUrl(named: AppConstants.Filenames.appLogFilename).deletingLastPathComponent(),
                                       wireguardProtocolFactory: wireguardFactory,
                                       openVpnProtocolFactory: openVpnFactory)
    }
}

// MARK: SessionServiceFactory
extension DependencyContainer: SessionServiceFactory {
    func makeSessionService() -> SessionService {
        return SessionServiceImplementation(factory: self)
    }
}

// MARK: StatusMenuViewModelFactory
extension DependencyContainer: StatusMenuViewModelFactory {
    func makeStatusMenuViewModel() -> StatusMenuViewModel {
        return StatusMenuViewModel(factory: self)
    }
}

// MARK: NEVPNManagerWrapperFactory
extension DependencyContainer: NEVPNManagerWrapperFactory {
    func makeNEVPNManagerWrapper() -> NEVPNManagerWrapper {
        NEVPNManager.shared()
    }
}

// MARK: NETunnelProviderManagerWrapperFactory
extension DependencyContainer: NETunnelProviderManagerWrapperFactory {
    func makeNewManager() -> NETunnelProviderManagerWrapper {
        NETunnelProviderManager()
    }

    func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            completionHandler(managers, error)
        }
    }
}

// MARK: AvailabilityCheckerResolverFactory
extension DependencyContainer: AvailabilityCheckerResolverFactory {
    func makeAvailabilityCheckerResolver(openVpnConfig: OpenVpnConfig, wireguardConfig: WireguardConfig) -> AvailabilityCheckerResolver {
        AvailabilityCheckerResolverImplementation(openVpnConfig: openVpnConfig, wireguardConfig: wireguardConfig)
    }
}
