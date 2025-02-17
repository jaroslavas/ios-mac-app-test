//
//  Created on 2022-09-30.
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
import NetworkExtension

extension NETunnelProviderProtocol {
    static let connectedLogicalIdKey = "PVPNLogicalID"
    static let connectedServerIpIdKey = "PVPNServerIpID"
    static let reconnectionEnabledKey = "ReconnectionEnabled"
    static let uidKey = "UID"
    static let wgProtocolKey = "wg-protocol"
    static let featureFlagOverridesKey = "FeatureFlagOverrides"

    private func ensureProviderConfig() {
        guard providerConfiguration == nil else { return }

        providerConfiguration = [:]
    }

    public var connectedLogicalId: String? {
        get {
            providerConfiguration?[Self.connectedLogicalIdKey] as? String ??
                providerConfiguration?["PVPNServerID"] as? String // old name for the key
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.connectedLogicalIdKey] = newValue
        }
    }

    public var connectedServerIpId: String? {
        get {
            providerConfiguration?[Self.connectedServerIpIdKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.connectedServerIpIdKey] = newValue
        }
    }

    public var appUid: uid_t? {
        get {
            providerConfiguration?[Self.uidKey] as? uid_t
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.uidKey] = newValue
        }
    }

    public var wgProtocol: String? {
        get {
            providerConfiguration?[Self.wgProtocolKey] as? String
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.wgProtocolKey] = newValue
        }
    }

    public var reconnectionEnabled: Bool? {
        get {
            providerConfiguration?[Self.reconnectionEnabledKey] as? Bool
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.reconnectionEnabledKey] = newValue
        }
    }

    public var featureFlagOverrides: [String: [String: Bool]]? {
        get {
            providerConfiguration?[Self.featureFlagOverridesKey] as? [String: [String: Bool]]
        }
        set {
            ensureProviderConfig()
            providerConfiguration?[Self.featureFlagOverridesKey] = newValue
        }
    }
}
