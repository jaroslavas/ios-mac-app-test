//
//  PacketTunnelProvider.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-05-17.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import NetworkExtension
import os
import WireGuardKit
import Logging

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var certificateRefreshManager: ExtensionCertificateRefreshManager!

    override init() {
        super.init()
        let storage = Storage()

        let dataTaskFactory = ConnectionTunnelDataTaskFactory(provider: self)
        let vpnAuthenticationStorage = VpnAuthenticationKeychain(accessGroup: WGConstants.keychainAccessGroup,
                                                                 storage: storage)
        certificateRefreshManager = ExtensionCertificateRefreshManager(storage: storage,
                                                                       dataTaskFactory: dataTaskFactory,
                                                                       vpnAuthenticationStorage: vpnAuthenticationStorage,
                                                                       keychain: AuthKeychain())
        setupLogging()
    }
    
    deinit {
        wg_log(.info, message: "PacketTunnelProvider deinited")
    }

    private func connectionEstablished() {
        certificateRefreshManager.start()
        #if CHECK_CONNECTIVITY
        startTestingConnectivity()
        #endif
    }

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { logLevel, message in
            wg_log(.info, message: message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let activationAttemptId = options?["activationAttemptId"] as? String
        let errorNotifier = ErrorNotifier(activationAttemptId: activationAttemptId)
        
        // Use shared defaults to get cert features that were set in the app
        Storage.setSpecificDefaults(defaults: UserDefaults(suiteName: AppConstants.AppGroups.main)!)

        #if FREQUENT_AUTH_CERT_REFRESH
        CertificateConstants.certificateDuration = "30 minutes"
        #endif

        wg_log(.info, message: "Starting tunnel from the " + (activationAttemptId == nil ? "OS directly" : "app"))
        flushLogsToFile() // Prevents empty logs in the app during the first WG connection

        guard let tunnelProviderProtocol = self.protocolConfiguration as? NETunnelProviderProtocol else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.info, message: "Error in guard 1: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }
        guard let tunnelConfiguration = tunnelProviderProtocol.asTunnelConfiguration() else {
            errorNotifier.notify(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            completionHandler(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)
            wg_log(.info, message: "Error in guard 2: \(PacketTunnelProviderError.savedProtocolConfigurationIsInvalid)")
            return
        }

        // Start the tunnel
        adapter.start(tunnelConfiguration: tunnelConfiguration) { adapterError in
            guard let adapterError = adapterError else {
                let interfaceName = self.adapter.interfaceName ?? "unknown"
                wg_log(.info, message: "Tunnel interface is \(interfaceName)")

                completionHandler(nil)
                
                self.connectionEstablished()
                
                return
            }

            switch adapterError {
            case .cannotLocateTunnelFileDescriptor:
                wg_log(.error, staticMessage: "Starting tunnel failed: could not determine file descriptor")
                errorNotifier.notify(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
                completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)

            case .dnsResolution(let dnsErrors):
                let hostnamesWithDnsResolutionFailure = dnsErrors.map { $0.address }
                    .joined(separator: ", ")
                wg_log(.error, message: "DNS resolution failed for the following hostnames: \(hostnamesWithDnsResolutionFailure)")
                errorNotifier.notify(PacketTunnelProviderError.dnsResolutionFailure)
                completionHandler(PacketTunnelProviderError.dnsResolutionFailure)

            case .setNetworkSettings(let error):
                wg_log(.error, message: "Starting tunnel failed with setTunnelNetworkSettings returning \(error.localizedDescription)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotSetNetworkSettings)
                completionHandler(PacketTunnelProviderError.couldNotSetNetworkSettings)

            case .startWireGuardBackend(let errorCode):
                wg_log(.error, message: "Starting tunnel failed with wgTurnOn returning \(errorCode)")
                errorNotifier.notify(PacketTunnelProviderError.couldNotStartBackend)
                completionHandler(PacketTunnelProviderError.couldNotStartBackend)

            case .invalidState:
                wg_log(.error, message: "Starting tunnel failed with invalidState")
                // Must never happen
                fatalError()
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        wg_log(.info, staticMessage: "Stopping tunnel")
        certificateRefreshManager.stop()
        #if CHECK_CONNECTIVITY
        self.stopTestingConnectivity()
        #endif

        adapter.stop { error in
            ErrorNotifier.removeLastErrorFile()

            if let error = error {
                wg_log(.error, message: "Failed to stop WireGuard adapter: \(error.localizedDescription)")
            }
            self.flushLogsToFile()
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        wg_log(.info, message: "Handle App Message size: \(messageData.count)")
        
        if messageData.count == 1 && messageData[0] == 101 {
            flushLogsToFile()
        } else if let completionHandler = completionHandler, messageData.count == 1 && messageData[0] == 0 {
            adapter.getRuntimeConfiguration { settings in
                var data: Data?
                if let settings = settings {
                    data = settings.data(using: .utf8)!
                }
                completionHandler(data)
            }
        } else {
            completionHandler?(nil)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        log.info("sleep()")

        #if CHECK_CONNECTIVITY
        self.stopTestingConnectivity()
        #endif

        certificateRefreshManager.stop {
            completionHandler()
        }
    }

    override func wake() {
        log.info("wake()")
        certificateRefreshManager.start()

        #if CHECK_CONNECTIVITY
        startTestingConnectivity()
        #endif
    }

    // MARK: - Logs

    // LoggingSystem crashes if bootstrap is called more than once during process lifetime, so we have to remember it was already set up
    private static var loggingSetupIsDone = false

    private func setupLogging() {
        // Our logger
        if !Self.loggingSetupIsDone {
            Self.loggingSetupIsDone = true
            LoggingSystem.bootstrap { _ in
                return WGLogHandler(formatter: WGLogFormatter())
            }
        }
        // WG logger
        Logger.configureGlobal(tagged: "PROTON-WG", withFilePath: FileManager.logFileURL?.path)
    }
    
    private func flushLogsToFile() {
        guard let path = FileManager.logTextFileURL?.path else { return }
        if Logger.global?.writeLog(to: path) ?? false {
            wg_log(.info, message: "flushLogsToFile written to file \(path) ")
        } else {
            wg_log(.info, message: "flushLogsToFile error while writing to file \(path) ")
        }
    }

    // MARK: - Connection tests

#if CHECK_CONNECTIVITY
    // Enable this in build settings if you want to debug connectivitiy issues.
    // It will ping API as well as 3rd party ip check site to check if we have the internet and are still connected to the proper server.
    // Please make sure this is NEVER enabled on Release builds!

    private var connectivityTimer: Timer?
    private var lastConnectivityCheck: Date = Date()

    private func startTestingConnectivity() {
        DispatchQueue.main.async {
            self.connectivityTimer?.invalidate()
            self.connectivityTimer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(self.checkConnectivity), userInfo: nil, repeats: true)
        }
    }

    private func stopTestingConnectivity() {
        DispatchQueue.main.async {
            self.connectivityTimer?.invalidate()
            self.connectivityTimer = nil
        }
    }

    @objc private func checkConnectivity() {
        let timeDiff = -lastConnectivityCheck.timeIntervalSinceNow
        if timeDiff > 60 * 3 {
            log.error("Seems like phone was sleeping! Last connectivity check time diff: \(timeDiff)")
        } else {
            log.info("Last connectivity check time diff: \(timeDiff)")
        }
        check(url: "https://api.protonvpn.ch/vpn/location")
        check(url: "https://api64.ipify.org/")
        lastConnectivityCheck = Date()
    }

    private func check(url urlString: String) {
        guard let url = URL(string: urlString), let host = url.host else {
            log.error("Can't get API endpoint hostname.", category: .api)
            return
        }
        let urlRequest = URLRequest(url: url)
        let dataTaskFactory = ConnectionTunnelDataTaskFactory(provider: self)

        let task = dataTaskFactory.dataTask(urlRequest) { data, response, error in
            let responseData = data != nil ? String(data:data!, encoding: .utf8) : "nil"
            log.debug("Host check finished", category: .net, metadata: ["host": "\(host)", "data":"\(String(describing: responseData))", "response": "\(String(describing: response))", "error": "\(String(describing: error))"])
        }
        task.resume()
    }

#endif
    
}

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}
