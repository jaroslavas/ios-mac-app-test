//
//  StatusMenuViewModel.swift
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

import Cocoa
import vpncore

protocol StatusMenuWindowModelFactory {
    func makeStatusMenuWindowModel() -> StatusMenuWindowModel
}

extension DependencyContainer: StatusMenuWindowModelFactory {
    func makeStatusMenuWindowModel() -> StatusMenuWindowModel {
        return StatusMenuWindowModel(factory: self)
    }
}

class StatusMenuWindowModel {
    
    typealias Factory = AppSessionManagerFactory & StatusMenuViewModelFactory & AppSessionRefresherFactory & AppSessionRefreshTimerFactory & VpnGatewayFactory
    private let factory: Factory
    
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    
    var contentChanged: (() -> Void)?
    
    init(factory: Factory) {
        self.factory = factory
        startObserving()
    }
    
    var isSessionEstablished: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    var isConnected: Bool {
        return vpnGateway.connection == .connected
    }
    
    var statusMenuViewController: StatusMenuViewController {
        let viewModel = factory.makeStatusMenuViewModel()
        return StatusMenuViewController(with: viewModel)
    }
    
    var statusIcon: StatusIcon {
        switch vpnGateway.connection {
        case .connected:
            return .connected
        case .connecting:
            return .connecting
        case .disconnected, .disconnecting:
            return .disconnected
        }
    }

    var appIcon: AppIcon {
        switch vpnGateway.connection {
        case .connected:
            return .active
        default:
            return .disconnected
        }
    }
    
    var isStatusIconBlinking: Bool {
        return vpnGateway.connection == .connecting
    }
    
    func requiresRefreshes(_ required: Bool) {
        if required {
            factory.makeAppSessionRefreshTimer().start(now: true)
        }
    }
    
    // MARK: - Private functions
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged),
                                               name: appSessionManager.sessionChanged, object: nil)
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if isSessionEstablished, let vpnGateway = notification.object as? VpnGatewayProtocol {
            sessionEstablished(vpnGateway: vpnGateway)
        } else {
            sessionEnded()
        }
        
        contentChanged?()
    }
    
    private func sessionEstablished(vpnGateway: VpnGatewayProtocol) {
        self.vpnGateway = vpnGateway
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange),
                                               name: VpnGateway.connectionChanged, object: nil)
    }
    
    private func sessionEnded() {
        NotificationCenter.default.removeObserver(self, name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: VpnGateway.connectionChanged, object: nil)
    }
    
    @objc private func handleChange() {
        contentChanged?()
    }
}

/// All possible status menu icons
enum StatusIcon {
    static let margin = 2
    static let size = Int(NSStatusBar.system.thickness) - margin * 2

    case connected
    case disconnected
    case connecting
    case unknown
}

enum AppIcon {
    case active
    case disconnected
}
