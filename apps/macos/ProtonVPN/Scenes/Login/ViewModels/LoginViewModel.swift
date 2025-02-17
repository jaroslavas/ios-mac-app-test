//
//  LoginViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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
import ProtonCore_Login
import ProtonCore_Networking
import ProtonCore_Authentication
import VPNShared

final class LoginViewModel {
    
    typealias Factory = NavigationServiceFactory &
                        PropertiesManagerFactory &
                        AppSessionManagerFactory &
                        CoreAlertServiceFactory &
                        UpdateManagerFactory &
                        ProtonReachabilityCheckerFactory &
                        NetworkingFactory &
                        SystemExtensionManagerFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
    private lazy var protonReachabilityChecker: ProtonReachabilityChecker = factory.makeProtonReachabilityChecker()
    private lazy var authHelper = AuthHelper()
    private lazy var loginService: Login = LoginService(api: factory.makeNetworking().apiService, authManager: authHelper, clientApp: .vpn, minimumAccountType: AccountType.username)
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()

    var logInInProgress: (() -> Void)?
    var logInFailure: ((String?) -> Void)?
    var logInFailureWithSupport: ((String?) -> Void)?
    var checkInProgress: ((Bool) -> Void)?
    var twoFactorRequired: (() -> Void)?
    var initialError: String?

    private(set) var isTwoFactorStep: Bool = false

    init (factory: Factory) {
        self.factory = factory
    }
    
    var startOnBoot: Bool {
        return propertiesManager.startOnBoot
    }
    
    func startOnBoot(enabled: Bool) {
        propertiesManager.startOnBoot = enabled
    }
    
    func logInSilently() {
        logInInProgress?()
        appSessionManager.attemptSilentLogIn { [weak self] result in
            switch result {
            case .success:
                NSApp.setActivationPolicy(.accessory)
                self?.silentlyCheckForUpdates()
            case let .failure(error):
                self?.specialErrorCaseNotification(error)
                self?.navService.handleSilentLoginFailure()
            }
        }
    }
    
    func logInAppeared() {
        guard initialError == nil else {
            logInFailure?(initialError)
            return
        }
        logInInProgress?()
        appSessionManager.attemptSilentLogIn { [weak self] result in
            switch result {
            case .success:
                self?.silentlyCheckForUpdates()
            case let .failure(error):
                self?.specialErrorCaseNotification(error)
                self?.logInFailure?((error as NSError) == ProtonVpnErrorConst.userCredentialsMissing ? nil : error.localizedDescription)
            }
        }
    }
    
    func logIn(username: String, password: String) {
        logInInProgress?()
        loginService.login(username: username, password: password, challenge: nil) { [weak self] result in
            self?.handleLoginResult(result: result)
        }
    }

    func provide2FACode(code: String) {
        logInInProgress?()
        loginService.provide2FACode(code) { [weak self] result in
            self?.handleLoginResult(result: result)
        }
    }

    func cancelTwoFactor() {
        isTwoFactorStep = false
    }

    func updateAvailableDomains() {
        loginService.updateAllAvailableDomains(type: AvailableDomainsType.login) { _ in }
    }

    private func handleLoginResult(result: Result<LoginStatus, LoginError>) {
        switch result {
        case let .success(status):
            switch status {
            case let .finished(data):
                appSessionManager.finishLogin(authCredentials: AuthCredentials(data.credential), success: { [weak self] in
                    self?.silentlyCheckForUpdates()

                    self?.sysexManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: true, actionHandler: { _ in })
                }, failure: { [weak self] error in
                    self?.handleError(error: error)
                })
            case .ask2FA:
                isTwoFactorStep = true
                twoFactorRequired?()
            case .askSecondPassword, .chooseInternalUsernameAndCreateInternalAddress:
                log.error("Unsupported login scenario", category: .app, metadata: ["result": "\(result)"])
                logInFailure?(LocalizedString.loginUnsupportedState)
            }
        case let .failure(error):
            handleLoginError(error: error)
        }
    }

    private func handleLoginError(error: LoginError) {
        // some login errors need to be handle in a specific way
        switch error {
        case let .invalidAccessToken(message: message):
            // after entering wrong 2FA code 3 times the access token gets invalidated
            // the users cannot continue entering the 2FA code, they need to start over
            // the state is reset back to the username + password form and error is shown
            isTwoFactorStep = false
            logInFailure?(message)
        case let .invalidCredentials(message: message), let .invalid2FACode(message: message):
            // invalid credentials or 2FA code entered, show the most specific error message
            logInFailure?(message)
        case let .generic(_, code: _, originalError: originalError):
            // if the error is a response error and the underlying error is a network or TLS error convert it to the app network error
            // this is needed so the basic error handling logic shows an alert that offers troubleshooting to the users
            if let responseError = originalError as? ResponseError, let underlyingError = responseError.underlyingError, underlyingError.isNetworkError || underlyingError.isTlsError {
                handleError(error: NetworkError.error(forCode: underlyingError.code))
                return
            }

            // otherwise just convert the login error to a classic error with the error code and the user facing error message
            handleError(error: NSError(code: error.bestShotAtReasonableErrorCode, localizedDescription: error.userFacingMessageInLogin))
        default:
            handleError(error: NSError(code: error.bestShotAtReasonableErrorCode, localizedDescription: error.userFacingMessageInLogin))
        }
    }

    private func handleError(error: Error) {
        specialErrorCaseNotification(error)

        let nsError = error as NSError
        if nsError.isTlsError || nsError.isNetworkError {
            let alert = UnreachableNetworkAlert(error: error, troubleshoot: { [weak self] in
                self?.alertService.push(alert: ConnectionTroubleshootingAlert())
            })
            alertService.push(alert: alert)
            logInFailure?(nil)
        } else if case ProtonVpnError.subuserWithoutSessions = error {
            let userRole = propertiesManager.user?.role ?? 0
            let role = SubuserWithoutConnectionsAlert.Role(rawValue: userRole) ?? .noOrganization
            alertService.push(alert: SubuserWithoutConnectionsAlert(role: role))
            isTwoFactorStep = false
            logInFailure?(nil)
        } else {
            logInFailure?(error.localizedDescription)
        }
    }
    
    private func specialErrorCaseNotification(_ error: Error) {
        if error is KeychainError ||
            (error as NSError).code == NetworkErrorCode.timedOut ||
            (error as NSError).code == ApiErrorCode.apiVersionBad ||
            (error as NSError).code == ApiErrorCode.appVersionBad {
            logInFailureWithSupport?(error.localizedDescription)
        }
    }
    
    private func silentlyCheckForUpdates() {
        updateManager.checkForUpdates(appSessionManager, silently: true)
    }
    
    func keychainHelpAction() {
        SafariService().open(url: CoreAppConstants.ProtonVpnLinks.supportCommonIssues)
    }
    
    func createAccountAction() {
        checkInProgress?(true)

        protonReachabilityChecker.check { [weak self] reachable in
            self?.checkInProgress?(false)

            if reachable {
                SafariService().open(url: CoreAppConstants.ProtonVpnLinks.signUp)
            } else {
                self?.alertService.push(alert: ProtonUnreachableAlert())
            }
        }
    }

    var helpPopoverViewModel: HelpPopoverViewModel {
        return HelpPopoverViewModel(navigationService: navService)
    }
}
