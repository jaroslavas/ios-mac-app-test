//
//  VpnGateway.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import VPNShared

public enum ConnectionStatus {
    
    case disconnected
    case connecting
    case connected
    case disconnecting
    
    static func forAppState(_ appState: AppState) -> ConnectionStatus {
        switch appState {
        case .disconnected, .aborted, .error:
            return .disconnected
        case .preparingConnection, .connecting:
            return .connecting
        case .connected:
            return .connected
        case .disconnecting:
            return .disconnecting
        }
    }
}

public enum ResolutionUnavailableReason {
    
    case upgrade(Int)
    case maintenance
    case existingConnection
    case protocolNotSupported
}

public enum RestrictedServerGroup {
    
    case all
    case country(code: String)
}

public enum ServerSelection {
    
    case fastest
    case random
}

public protocol VpnGatewayProtocol: AnyObject {
    
    var connection: ConnectionStatus { get }
    var lastConnectionRequest: ConnectionRequest? { get }

    static var connectionChanged: Notification.Name { get }
    static var activeServerTypeChanged: Notification.Name { get }
    static var needsReconnectNotification: Notification.Name { get }
    
    func userTier() throws -> Int
    func changeActiveServerType(_ serverType: ServerType)
    func autoConnect()
    func quickConnect(trigger: TelemetryDimensions.VPNTrigger)
    func quickConnectConnectionRequest(trigger: TelemetryDimensions.VPNTrigger) -> ConnectionRequest
    func connectTo(country countryCode: String, ofType serverType: ServerType, trigger: TelemetryDimensions.VPNTrigger)
    func connectTo(country countryCode: String, city: String)
    func connectTo(server: ServerModel)
    func connectTo(profile: Profile)
    func retryConnection()
    func reconnect(with netShieldType: NetShieldType)
    func reconnect(with connectionProtocol: ConnectionProtocol)
    func reconnect(with natType: NATType)
    func connect(with request: ConnectionRequest?)
    func stopConnecting(userInitiated: Bool)
    func disconnect()
    func disconnect(completion: @escaping () -> Void)
    func postConnectionInformation()
}

public protocol VpnGatewayFactory {
    func makeVpnGateway() -> VpnGatewayProtocol
}

public class VpnGateway: VpnGatewayProtocol {
    private enum ConnectionType {
        case quick
        case auto
        case country(code: String, type: ServerType)
        case server(ServerModel)
        case profile(Profile)
    }
    
    private let vpnApiService: VpnApiService
    private let appStateManager: AppStateManager
    private let profileManager: ProfileManager
    private let serverTierChecker: ServerTierChecker
    private let vpnKeychain: VpnKeychainProtocol
    private let authKeychain: AuthKeychainHandle
    private let availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory
    
    private let serverStorage: ServerStorage
    private let propertiesManager: PropertiesManagerProtocol

    private let siriHelper: SiriHelperProtocol?
    
    private var tier: Int {
        return (try? userTier()) ?? CoreAppConstants.VpnTiers.free
    }

    private var serverManager: ServerManager {
        return ServerManagerImplementation.instance(forTier: tier, serverStorage: serverStorage)
    }
   
    private var serverTypeToggle: ServerType {
        return propertiesManager.secureCoreToggle ? .secureCore : .standard
    }

    private var globalConnectionProtocol: ConnectionProtocol {
        if propertiesManager.smartProtocol {
            return .smartProtocol
        }

        return .vpnProtocol(propertiesManager.vpnProtocol)
    }
    
    private var connectionPreparer: VpnConnectionPreparer?
    
    public static let connectionChanged = Notification.Name("VpnGatewayConnectionChanged")
    public static let activeServerTypeChanged = Notification.Name("VpnGatewayActiveServerTypeChanged")
    public static let needsReconnectNotification = Notification.Name("VpnManagerNeedsReconnect")
    
    public weak var alertService: CoreAlertService? {
        didSet {
            serverTierChecker.alertService = alertService
        }
    }
    
    public var connection: ConnectionStatus
    
    public var lastConnectionRequest: ConnectionRequest? {
        return propertiesManager.lastConnectionRequest
    }
    
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private var netShieldType: NetShieldType {
        return netShieldPropertyProvider.netShieldType
    }

    private let natTypePropertyProvider: NATTypePropertyProvider
    private var natType: NATType {
        return natTypePropertyProvider.natType
    }

    private let safeModePropertyProvider: SafeModePropertyProvider
    private var safeMode: Bool? {
        return safeModePropertyProvider.safeMode
    }

    let interceptPolicies: [VpnConnectionInterceptPolicyItem]

    public typealias Factory = VpnApiServiceFactory &
        AppStateManagerFactory &
        CoreAlertServiceFactory &
        VpnKeychainFactory &
        AuthKeychainHandleFactory &
        SiriHelperFactory &
        NetShieldPropertyProviderFactory &
        NATTypePropertyProviderFactory &
        SafeModePropertyProviderFactory &
        PropertiesManagerFactory &
        ProfileManagerFactory &
        AvailabilityCheckerResolverFactory &
        ServerStorageFactory &
        VpnConnectionInterceptDelegate

    public convenience init(_ factory: Factory) {
        self.init(vpnApiService: factory.makeVpnApiService(),
                  appStateManager: factory.makeAppStateManager(),
                  alertService: factory.makeCoreAlertService(),
                  vpnKeychain: factory.makeVpnKeychain(),
                  authKeychain: factory.makeAuthKeychainHandle(),
                  siriHelper: factory.makeSiriHelper(),
                  netShieldPropertyProvider: factory.makeNetShieldPropertyProvider(),
                  natTypePropertyProvider: factory.makeNATTypePropertyProvider(),
                  safeModePropertyProvider: factory.makeSafeModePropertyProvider(),
                  propertiesManager: factory.makePropertiesManager(),
                  profileManager: factory.makeProfileManager(),
                  availabilityCheckerResolverFactory: factory,
                  vpnInterceptPolicies: factory.vpnConnectionInterceptPolicies,
                  serverStorage: factory.makeServerStorage())
    }

    public init(vpnApiService: VpnApiService, appStateManager: AppStateManager, alertService: CoreAlertService, vpnKeychain: VpnKeychainProtocol, authKeychain: AuthKeychainHandle, siriHelper: SiriHelperProtocol? = nil, netShieldPropertyProvider: NetShieldPropertyProvider, natTypePropertyProvider: NATTypePropertyProvider, safeModePropertyProvider: SafeModePropertyProvider, propertiesManager: PropertiesManagerProtocol, profileManager: ProfileManager, availabilityCheckerResolverFactory: AvailabilityCheckerResolverFactory, vpnInterceptPolicies: [VpnConnectionInterceptPolicyItem] = [], serverStorage: ServerStorage) {
        self.vpnApiService = vpnApiService
        self.appStateManager = appStateManager
        self.alertService = alertService
        self.vpnKeychain = vpnKeychain
        self.authKeychain = authKeychain
        self.siriHelper = siriHelper
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.propertiesManager = propertiesManager
        self.profileManager = profileManager
        self.availabilityCheckerResolverFactory = availabilityCheckerResolverFactory
        serverTierChecker = ServerTierChecker(alertService: alertService, vpnKeychain: vpnKeychain)

        let state = appStateManager.state
        self.connection = ConnectionStatus.forAppState(state)
        self.interceptPolicies = vpnInterceptPolicies
        self.serverStorage = serverStorage

        if case .connected = state, let activeServer = appStateManager.activeConnection()?.server {
            changeActiveServerType(activeServer.serverType)
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appStateChanged),
                                               name: .AppStateManager.stateChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(userPlanChanged),
                                               name: type(of: vpnKeychain).vpnPlanChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(userBecameDelinquent),
                                               name: type(of: vpnKeychain).vpnUserDelinquent,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reconnectOnNotification),
                                               name: Self.needsReconnectNotification,
                                               object: nil)
    }
    
    public func userTier() throws -> Int {
        return try vpnKeychain.fetchCached().maxTier
    }
    
    public func changeActiveServerType(_ serverType: ServerType) {
        guard serverTypeToggle != serverType else { return }
        
        propertiesManager.secureCoreToggle = serverType == .secureCore
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            NotificationCenter.default.post(name: VpnGateway.activeServerTypeChanged, object: self.connection)
        }
    }
    
    public func autoConnect() {
        appStateManager.isOnDemandEnabled { [weak self] enabled in
            guard let self = self, !enabled else {
                return
            }

            if let username = self.authKeychain.fetch()?.username,
               let autoConnectProfileId = self.propertiesManager.getAutoConnect(for: username).profileId,
               let profile = self.profileManager.profile(withId: autoConnectProfileId) {
                self.connectTo(profile: profile)
            } else {
                self.quickConnect(trigger: .auto)
            }
        }
    }
    
    public func quickConnect(trigger: TelemetryDimensions.VPNTrigger) {
        connect(with: quickConnectConnectionRequest(trigger: trigger))
    }
    
    public func quickConnectConnectionRequest(trigger: TelemetryDimensions.VPNTrigger) -> ConnectionRequest {
        if let username = authKeychain.fetch()?.username,
           let quickConnectProfileId = propertiesManager.getQuickConnect(for: username),
           let profile = profileManager.profile(withId: quickConnectProfileId) {
            return profile.connectionRequest(withDefaultNetshield: netShieldType, withDefaultNATType: natType, withDefaultSafeMode: safeMode, trigger: trigger)
        } else {
            return ConnectionRequest(serverType: serverTypeToggle, connectionType: .fastest, connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil, trigger: trigger)
        }
    }
    
    public func connectTo(country countryCode: String, ofType serverType: ServerType, trigger: TelemetryDimensions.VPNTrigger = .country) {
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(countryCode, .fastest), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil, trigger: trigger)
        
        connect(with: connectionRequest)
    }

    public func connectTo(country countryCode: String, city: String) {
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .city(country: countryCode, city: city), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil, trigger: .city)

        connect(with: connectionRequest)
    }
    
    public func connectTo(server: ServerModel) {
        let countryType = CountryConnectionRequestType.server(server)
        let connectionRequest = ConnectionRequest(serverType: serverTypeToggle, connectionType: .country(server.countryCode, countryType), connectionProtocol: globalConnectionProtocol, netShieldType: netShieldType, natType: natType, safeMode: safeMode, profileId: nil, trigger: .server)
        
        connect(with: connectionRequest)
    }
    
    public func connectTo(profile: Profile) {
        let connectionRequest = profile.connectionRequest(withDefaultNetshield: netShieldType, withDefaultNATType: natType, withDefaultSafeMode: safeMode, trigger: .profile)
        connect(with: connectionRequest)
    }
    
    public func retryConnection() {
        connect(with: lastConnectionRequest)
    }
    
    public func reconnect(with netShieldType: NetShieldType) {
        connect(with: lastConnectionRequest?.withChanged(netShieldType: netShieldType))
    }

    public func reconnect(with natType: NATType) {
        connect(with: lastConnectionRequest?.withChanged(natType: natType))
    }

    public func reconnect(with safeMode: Bool) {
        connect(with: lastConnectionRequest?.withChanged(safeMode: safeMode))
    }
    
    public func reconnect(with connectionProtocol: ConnectionProtocol) {
        disconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(CoreAppConstants.protocolChangeDelay), execute: { // Delay enhances reconnection success rate
                let connectionRequest = self.lastConnectionRequest?.withChanged(connectionProtocol: connectionProtocol)
                self.connect(with: connectionRequest)
            })
        }
    }
    
    public func connect(with request: ConnectionRequest?) {
        siriHelper?.donateQuickConnect() // Change to another donation when appropriate
        propertiesManager.lastConnectionRequest = request
        
        guard let request else {
            gatherParametersAndConnect(with: globalConnectionProtocol, server: appStateManager.activeConnection()?.server, netShieldType: netShieldType, natType: natType, safeMode: safeMode)
            return
        }
        
        gatherParametersAndConnect(with: request.connectionProtocol, server: selectServer(connectionRequest: request), netShieldType: request.netShieldType, natType: natType, safeMode: safeMode)
    }
    
    private func selectServer(connectionRequest: ConnectionRequest) -> ServerModel? {
        do {
            let currentUserTier = try self.userTier() // accessing from the keychain for each server is very expensive
            
            let type = connectionRequest.serverType == .unspecified ? serverTypeToggle : connectionRequest.serverType
            
            let selector = VpnServerSelector(serverType: type,
                                             userTier: currentUserTier,
                                             serverGrouping: serverManager.grouping(for: type),
                                             connectionProtocol: connectionRequest.connectionProtocol,
                                             smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                             appStateGetter: { [unowned self] in
                self.appStateManager.state
            })
            selector.changeActiveServerType = { [unowned self] serverType in
                self.changeActiveServerType(serverType)
            }
            selector.notifyResolutionUnavailable = { [unowned self] forSpecificCountry, type, reason in
                self.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
            }
            
            let selected = selector.selectServer(connectionRequest: connectionRequest)
            log.debug("Server selected: \(selected?.logDescription ?? "-")", category: .connectionConnect)
            return selected
            
        } catch {
            alertService?.push(alert: CannotAccessVpnCredentialsAlert())
            return nil
        }
    }
    
    public func stopConnecting(userInitiated: Bool) {
        NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.abort)
        log.info("Connecting cancelled, userInitiated: \(userInitiated)", category: .connectionConnect)
        connectionPreparer = nil
        appStateManager.cancelConnectionAttempt()
    }
    
    public func disconnect() {
        disconnect {}
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        let completionWrapper: () -> Void = { [weak self] in
            completion()
            
            guard let self = self else {
                return
            }
            
            self.vpnApiService.refreshServerInfoIfIpChanged(lastKnownIp: self.propertiesManager.userLocation?.ip) { [weak self] result in
                guard let self = self else {
                    return
                }

                switch result {
                case let .success(properties):
                    if let userLocation = properties.location {
                        self.propertiesManager.userLocation = userLocation
                    }
                    if let services = properties.streamingServices {
                        self.propertiesManager.streamingServices = services.streamingServices
                    }
                    self.serverStorage.store(properties.serverModels)
                    self.profileManager.refreshProfiles()
                case .failure:
                    // Ignore failures as this is a non-critical call
                    break
                }
            }
        }
        
        siriHelper?.donateDisconnect()
        appStateManager.disconnect(completion: completionWrapper)
    }
    
    // MARK: - Private functions
    
    private func notifyResolutionUnavailable(forSpecificCountry: Bool, type: ServerType, reason: ResolutionUnavailableReason) {
        log.warning("Server resolution unavailable", category: .connectionConnect, metadata: ["forSpecificCountry": "\(forSpecificCountry)", "type": "\(type)", "reason": "\(reason)"])
        stopConnecting(userInitiated: false)
        serverTierChecker.notifyResolutionUnavailable(forSpecificCountry: forSpecificCountry, type: type, reason: reason)
    }

    /// Determine all of the different features we want to use for the connection, and then go on to the next connection step.
    ///
    /// Gathers the connection protocol (including smart protocol details) and kill switch setting. According to these set values and the
    /// configuration of the hardware, the options specified in `VpnConnectionInterceptPolicyItem` may change this configuration fetched
    /// from settings, possibly according to alerts displayed to the user whether they want to proceed with their normal settings.
    private func gatherParametersAndConnect(with connectionProtocol: ConnectionProtocol, server: ServerModel?, netShieldType: NetShieldType, natType: NATType, safeMode: Bool?) {
        guard let server else {
            return
        }

        var connectionProtocol = connectionProtocol
        let killSwitch = propertiesManager.killSwitch
        var smartProtocolConfig = propertiesManager.smartProtocolConfig
            .configWithWireGuard(tlsEnabled: propertiesManager.featureFlags.wireGuardTls)

        DispatchQueue.global(qos: .userInitiated).async {
            for policy in self.interceptPolicies {
                guard !self.applyInterceptPolicy(policy: policy,
                                                 connectionProtocol: &connectionProtocol,
                                                 smartProtocolConfig: &smartProtocolConfig,
                                                 killSwitch: killSwitch) else {
                    break
                }
            }

            self.propertiesManager.lastPreparedServer = server
            let availabilityCheckerResolver = self.availabilityCheckerResolverFactory
                .makeAvailabilityCheckerResolver(openVpnConfig: self.propertiesManager.openVpnConfig,
                                                 wireguardConfig: self.propertiesManager.wireguardConfig)

            self.connectionPreparer = VpnConnectionPreparer(appStateManager: self.appStateManager,
                                                            vpnApiService: self.vpnApiService,
                                                            alertService: self.alertService,
                                                            serverTierChecker: self.serverTierChecker,
                                                            vpnKeychain: self.vpnKeychain,
                                                            serverStorage: self.serverStorage,
                                                            availabilityCheckerResolver: availabilityCheckerResolver,
                                                            smartProtocolConfig: smartProtocolConfig,
                                                            openVpnConfig: self.propertiesManager.openVpnConfig,
                                                            wireguardConfig: self.propertiesManager.wireguardConfig)

            DispatchQueue.main.async {
                self.appStateManager.prepareToConnect()
                self.connectionPreparer?.determineServerParametersAndConnect(with: connectionProtocol, to: server, netShieldType: netShieldType, natType: natType, safeMode: safeMode)
            }
        }
    }

    /// - Returns: Whether or not the given policy changed connection settings.
    private func applyInterceptPolicy(policy: VpnConnectionInterceptPolicyItem,
                                      connectionProtocol: inout ConnectionProtocol,
                                      smartProtocolConfig: inout SmartProtocolConfig,
                                      killSwitch: Bool) -> Bool {
        let group = DispatchGroup()
        group.enter()

        var result: VpnConnectionInterceptResult = .allow
        policy.shouldIntercept(connectionProtocol, isKillSwitchOn: killSwitch) { interceptResult in
            result = interceptResult
            group.leave()
        }
        group.wait()

        guard case .intercept(let parameters) = result else {
            return false
        }

        if parameters.smartProtocolWithoutWireGuard {
            smartProtocolConfig = smartProtocolConfig.configWithWireGuard(enabled: false)
        }
        if parameters.disableKillSwitch {
            self.propertiesManager.killSwitch = false
        }
        if connectionProtocol != parameters.newProtocol {
            connectionProtocol = parameters.newProtocol
        }

        return true
    }

    public func postConnectionInformation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            NotificationCenter.default.post(name: VpnGateway.connectionChanged,
                                            object: self.connection,
                                            userInfo: [AppState.appStateKey: self.appStateManager.state])
        }
    }
    
    @objc private func appStateChanged(_ notification: Notification) {
        guard let state = notification.object as? AppState else {
            return
        }
        connection = ConnectionStatus.forAppState(state)
        postConnectionInformation()
    }

    @objc private func reconnectOnNotification(_ notification: Notification) {
        connect(with: lastConnectionRequest)
    }
}

fileprivate extension VpnGateway {
    @objc func userPlanChanged( _ notification: Notification ) {
        guard let downgradeInfo = notification.object as? VpnDowngradeInfo else { return }

        if downgradeInfo.to.maxTier < CoreAppConstants.VpnTiers.plus {
            propertiesManager.secureCoreToggle = false
        }
        
        if downgradeInfo.to.maxTier < CoreAppConstants.VpnTiers.basic {
            netShieldPropertyProvider.resetForIneligibleUser()
            natTypePropertyProvider.resetForIneligibleUser()
            safeModePropertyProvider.resetForIneligibleUser()
        }
        
        guard downgradeInfo.to.maxTier < downgradeInfo.from.maxTier else { return }
        
        var reconnectInfo: ReconnectInfo?
        
        if case .connected = connection, let server = appStateManager.activeConnection()?.server, server.tier > downgradeInfo.to.maxTier {
            reconnectInfo = reconnectServer(downgradeInfo, oldServer: server)
        }

        let alert = UserPlanDowngradedAlert(reconnectInfo: reconnectInfo)

        alertService?.push(alert: alert)
    }
    
    @objc func userBecameDelinquent(_ notification: Notification) {
        guard let downgradeInfo = notification.object as? VpnDowngradeInfo else { return }

        var oldServer: ServerModel?
        if case .connected = self.connection,
           let server = self.appStateManager.activeConnection()?.server,
           server.tier > downgradeInfo.to.maxTier {
            oldServer = server
        }

        self.disconnect {
            self.vpnApiService.clientCredentials { [unowned self] result in
                switch result {
                case let .success(credentials):
                    self.vpnKeychain.store(vpnCredentials: credentials)
                    
                    let reconnectInfo = self.reconnectServer(downgradeInfo, oldServer: oldServer)
                    let alert = UserBecameDelinquentAlert(reconnectInfo: reconnectInfo)
                    self.alertService?.push(alert: alert)
                case let .failure(error):
                    log.error("Error received: \(error)", category: .connectionConnect)
                }
            }
        }
    }
    
    private func reconnectServer( _ downgradeInfo: VpnDowngradeInfo, oldServer: ServerModel? ) -> ReconnectInfo? {
        guard let previousServer = oldServer else { return nil }

        let tier = downgradeInfo.to.maxTier
        let serverManager = ServerManagerImplementation.instance(forTier: downgradeInfo.to.maxTier, serverStorage: serverStorage)
        let selector = VpnServerSelector(serverType: .unspecified,
                                         userTier: tier,
                                         serverGrouping:
                                            serverManager.grouping(for: serverTypeToggle),
                                         connectionProtocol: propertiesManager.connectionProtocol,
                                         smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                         appStateGetter: { [unowned self] in
            self.appStateManager.state
        })
        
        let request = ConnectionRequest(
            serverType: serverTypeToggle,
            connectionType: .fastest,
            connectionProtocol: globalConnectionProtocol,
            netShieldType: netShieldPropertyProvider.netShieldType,
            natType: natTypePropertyProvider.natType,
            safeMode: safeModePropertyProvider.safeMode,
            profileId: nil,
            trigger: nil)
        
        guard let toServer = selector.selectServer(connectionRequest: request) else { return nil }
        propertiesManager.lastConnectionRequest = request
        self.gatherParametersAndConnect(with: request.connectionProtocol, server: toServer, netShieldType: request.netShieldType, natType: request.natType, safeMode: request.safeMode)
        return ReconnectInfo(fromServer: .init(name: previousServer.name,
                                               image: .flag(countryCode: previousServer.countryCode) ?? Image()),
                             toServer: .init(name: toServer.name,
                                             image: .flag(countryCode: toServer.countryCode) ?? Image()))
    }
}
