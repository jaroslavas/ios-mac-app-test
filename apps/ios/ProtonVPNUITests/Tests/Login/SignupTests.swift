//
//  NewSignupTests.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-09-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import pmtest
import ProtonCore_Doh
import ProtonCore_QuarkCommands
import ProtonCore_TestingToolkit

class SignupTests: ProtonVPNUITests {
    
    var doh: DoH & ServerConfig {
          return CustomServerConfigDoH(
            signupDomain: ObfuscatedConstants.blackSignupDomain,
            captchaHost: ObfuscatedConstants.blackCaptchaHost,
            humanVerificationV3Host: ObfuscatedConstants.blackHumanVerificationV3Host,
            accountHost: ObfuscatedConstants.blackAccountHost,
            defaultHost: ObfuscatedConstants.blackDefaultHost,
            apiHost: ObfuscatedConstants.apiHost,
            defaultPath: ObfuscatedConstants.blackDefaultPath
          )
      }
    
    lazy var quarkCommands = QuarkCommands(doh: doh)
    private let mainRobot = MainRobot()
    private let signupRobot = SignupRobot()
    
    override func setUp() {
        super.setUp()
        logoutIfNeeded()
        // This method is asynchronous, but it still works, because it's enough time before the actual UI testing starts
        quarkCommands.unban { result in
            print("Unban finished: \(result)") // swiftlint:disable:this no_print
        }
     }
    
    func testSignupExistingInternalAccount() {
        
        let email = "vpnfree"
        
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: SignupRobot.self)
            .verify.usernameErrorIsShown()
    }
   
    func testSignupNewInternalAccountWithRecoveryEmailSuccess() {
       
        let email = StringUtils().randomAlphanumericString(length: 5)
        let testEmail = StringUtils().randomAlphanumericString(length: 5) + "@mail.com"
        let randomEmail = StringUtils().randomAlphanumericString(length: 5) + "@mail.com"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let code = "666666"
        let plan = "Proton VPN Free"

        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .enterPassword(password)
            .enterRepeatPassword(password)
            .nextButtonTap(robot: RecoveryRobot.self)
            .insertRecoveryEmail(testEmail)
            .nextButtonTap(robot: SignupHumanVerificationV3Robot.self)
            .verify.humanVerificationScreenIsShown()
            .performEmailVerificationV3(email: randomEmail, code: code, to: CreatingAccountRobot.self)
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown()
        skipOnboarding()
        mainRobot
            .goToSettingsTab()
            .verify.userIsCreated(email, plan)
    }
    
    func testSignupNewExternalAccountSuccess() {
        let email = StringUtils().randomAlphanumericString(length: 7) + "@mail.com"
        let code = "666666"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let plan = "Proton VPN Free"
    
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: AccountVerificationRobot.self)
            .verify.accountVerificationScreenIsShown()
            .enterVerificationCode(code)
            .nextButtonTap(robot: PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .enterPassword(password)
            .enterRepeatPassword(password)
            .nextButtonTap(robot: PaymentsRobot.self)
            .verify.subscriptionScreenIsShown()
    }
    
    func testSignupExistingExternalAccount() {

        let email = "vpnfree@gmail.com"
        let code = "666666"
        
        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: AccountVerificationRobot.self)
            .verify.accountVerificationScreenIsShown()
            .enterVerificationCode(code)
            .nextButtonTap(robot: LoginRobot.self)
            .verify.emailAddressAlreadyExists()
            .verify.loginScreenIsShown()
    }
    
    /// Test showing standard plan (not Black Friday 2022 plan) for upgrade after successful signup
    func testSignupNewInternalAccountUpgradePlans() {
       
        let email = StringUtils().randomAlphanumericString(length: 5)
        let testEmail = StringUtils().randomAlphanumericString(length: 5) + "@mail.com"
        let randomEmail = StringUtils().randomAlphanumericString(length: 5) + "@mail.com"
        let password = StringUtils().randomAlphanumericString(length: 8)
        let code = "666666"

        changeEnvToBlackIfNeeded()
        useAndContinueTap()
        mainRobot
            .showSignup()
            .verify.signupScreenIsShown()
            .enterEmail(email)
            .nextButtonTap(robot: PasswordRobot.self)
            .verify.passwordScreenIsShown()
            .enterPassword(password)
            .enterRepeatPassword(password)
            .nextButtonTap(robot: RecoveryRobot.self)
            .insertRecoveryEmail(testEmail)
            .nextButtonTap(robot: SignupHumanVerificationV3Robot.self)
            .verify.humanVerificationScreenIsShown()
            .performEmailVerificationV3(email: randomEmail, code: code, to: CreatingAccountRobot.self)
            .verify.creatingAccountScreenIsShown()
            .verify.summaryScreenIsShown()
            .skipOnboarding()
            .nextOnboardingStep()
            .skipOnboarding()
            .startUsingProtonVpn()
            .startUpgrade()
            .verifyStaticText("Get Plus")
            .sleepFor(1)
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "VPN Plus")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "for 1 year")
            .verifyTableCellStaticText(cellName: "PlanCell.VPN_Plus", name: "$99.99")
    }

}
