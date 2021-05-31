//
//  ReportBugRobot.swift
//  ProtonVPNUITests
//
//  Created by Egle Predkelyte on 2021-05-28.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import PMTestAutomation
import XCTest

fileprivate let vpnLogsSwitch = "vpn logs"
fileprivate let contactEmailInput = "Contact email"
fileprivate let yourMessageInput = "Your message..."
fileprivate let reportMessaheTitle = "REPORT MESSAGE"
fileprivate let sendReportButton = "Send Report"
fileprivate let invalidEmailMessage = "Invalid email address"
fileprivate let bugReportSuccesslMessage = "Thank you for your report"
fileprivate let okButton = "OK"

class ReportBugRobot: CoreElements {
    
    let verify = Verify()

    func fillBugReportForm(_ email: String, _ message: String) -> ReportBugRobot {
        swittch(vpnLogsSwitch).tap()
        return typeEmailAndMessage(email, message)
    }
    
    func typeEmailOnly(_ email: String) -> ReportBugRobot {
        textField(contactEmailInput).tap().typeText(email)
        return ReportBugRobot()
    }
    
    func sendBugReport() -> ReportBugRobot {
        button(sendReportButton).checkExists()
        button(sendReportButton).tap()
        return ReportBugRobot()
    }
    
    func closeBugReporForm() -> SettingsRobot {
        button(okButton).tap()
        return SettingsRobot()
    }
    
    private func typeEmailAndMessage(_ email: String, _ message: String) -> ReportBugRobot {
        textField(contactEmailInput).tap().typeText(email)
        staticText(yourMessageInput).tap()
        XCUIApplication().typeText(message)
        return self
    }
    
    class Verify: CoreElements {
        
        @discardableResult
        func bugReportisSent() -> ReportBugRobot {
            staticText(bugReportSuccesslMessage).wait().checkExists()
            return ReportBugRobot()
        }
        
        @discardableResult
        func errorMessageIsShown() -> ReportBugRobot {
            staticText(invalidEmailMessage).wait().checkExists()
            return ReportBugRobot()
        }
    }
}
