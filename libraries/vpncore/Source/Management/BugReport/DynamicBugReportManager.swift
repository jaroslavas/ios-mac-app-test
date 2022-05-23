//
//  Created on 2022-01-14.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import ProtonCore_APIClient
import BugReport

#if os(iOS)
import UIKit
#elseif os(macOS)

#endif

public protocol DynamicBugReportManagerFactory {
    func makeDynamicBugReportManager() -> DynamicBugReportManager
}

public class DynamicBugReportManager {
    
    public var model: BugReportModel = .mock
    public var prefilledEmail: String {
        get {
            return self.propertiesManager.reportBugEmail ?? ""
        }
        set {
            self.propertiesManager.reportBugEmail = newValue
        }
    }
    public var prefilledUsername: String {
        return AuthKeychain.fetch()?.username ?? ""
    }
    
    public var closeBugReportHandler: (() -> Void)? // To not have a dependency on windowService
    
    private var api: ReportsApiService
    private var storage: DynamicBugReportStorage
    private var alertService: CoreAlertService
    private var propertiesManager: PropertiesManagerProtocol
    private var timer: Timer?
    private let updateChecker: UpdateChecker
    private let vpnKeychain: VpnKeychainProtocol
    
    public init(api: ReportsApiService, storage: DynamicBugReportStorage, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol, updateChecker: UpdateChecker, vpnKeychain: VpnKeychainProtocol) {
        self.api = api
        self.storage = storage
        self.alertService = alertService
        self.propertiesManager = propertiesManager
        self.updateChecker = updateChecker
        self.vpnKeychain = vpnKeychain
        
        model = storage.fetch() ?? getDefaultConfig()
        setupRefresh()
    }
    
    // Refresh config on every app start and then once a day
    private func setupRefresh() {
        loadConfig()
        timer = Timer(fire: Date().addingTimeInterval(.day), interval: .day, repeats: true, block: { _ in self.loadConfig() })
    }
    
    private func loadConfig() {
        api.dynamicBugReportConfig { result in
            switch result {
            case .success(let config):
                self.model = config
                self.storage.store(config)
                log.debug("Dynamic bug report config downloaded and saved", category: .app)
                
            case .failure(let error):
                log.debug("Dynamic bug report config download error", category: .app, event: .error, metadata: ["error": "\(error)"])
                // Ignoring this error as we have default config
            }
        }
    }
    
    private func getDefaultConfig() -> BugReportModel {
        let bundle = Bundle.vpnCore
        guard let configFile = bundle.url(forResource: "BugReportConfig", withExtension: "json") else {
            log.error("BugReportConfig.json file not found. Returning empty config.")
            return BugReportModel()
        }
        do {
            let data = try Data(contentsOf: configFile)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .custom(decapitalizeFirstLetter)
            return try decoder.decode(BugReportModel.self, from: data)
            
        } catch {
            return BugReportModel()
        }
    }
    
    private func fillReportBug(withData data: BugReportResult) -> ReportBug {
        #if os(iOS)
        let os = "iOS"
        let osVersion = UIDevice.current.systemVersion
        #elseif os(macOS)
        let os = "MacOS"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

        var report = ReportBug(os: os,
                               osVersion: osVersion,
                               client: "App",
                               clientVersion: "\(appVersion) (\(appBuild))",
                               clientType: 2,
                               title: "Report from \(os) app",
                               description: data.text,
                               username: data.username,
                               email: data.email,
                               country: propertiesManager.userLocation?.country ?? "",
                               ISP: propertiesManager.userLocation?.isp ?? "",
                               plan: (try? vpnKeychain.fetchCached().accountPlan.description) ?? "")
        
        if data.logs {
//            report.files = prepareLog(files: logFilesProvider.logFiles.compactMap { $0.1 }.reachable())
        }
        
        return report
    }
    
    // BugReportDelegate
    public var updateAvailabilityChanged: ((Bool) -> Void)?
    
}

extension DynamicBugReportManager: BugReportDelegate {
    public func send(form: BugReportResult, result: @escaping (SendReportResult) -> Void) {
        if form.logs {
            propertiesManager.logCurrentState()
        }
        let report = fillReportBug(withData: form)
        api.report(bug: report) { requestResult in
            self.deleteTempLog(files: report.files)

            switch requestResult {
            case .success:
                self.prefilledEmail = report.email
                result(.success(()))

            case .failure(let error):
                result(.failure(error))
            }
        }
    }
    
    public func finished() {
        closeBugReportHandler?()
    }
    
    public func troubleshootingRequired() {
        alertService.push(alert: ConnectionTroubleshootingAlert())
    }

    public func updateApp() {
        return updateChecker.startUpdate()
    }
    
    public func checkUpdateAvailability() {
        self.updateChecker.isUpdateAvailable { available in
            self.updateAvailabilityChanged?(available)
        }
    }

    // MARK: - Log files

    /// Moves log files to temp folder so they are not changed/deleted before networking lib uploads them
    private func prepareLog(files: [URL]) -> [URL] {
        let fileManager = FileManager.default
        return files.compactMap { fileUrl -> URL? in
            do {
                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(fileUrl.lastPathComponent)
                if fileManager.fileExists(atPath: tempFile.path) {
                    try fileManager.removeItem(at: tempFile)
                }
                try fileManager.copyItem(at: fileUrl, to: tempFile)
                return tempFile
            } catch {
                log.error("Can't move log file", category: .app, event: .error, metadata: ["error": "\(error)"])
            }
            return nil
        }
    }

    /// Deletes temp log files after upload is done
    private func deleteTempLog(files: [URL]) {
        files.forEach { file in
            try? FileManager.default.removeItem(at: file)
        }
    }
}
