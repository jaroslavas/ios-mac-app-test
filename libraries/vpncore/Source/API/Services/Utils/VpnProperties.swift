//
//  VpnProperties.swift
//  vpncore - Created on 06/05/2020.
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
//

import ProtonCore_DataModel

public struct VpnProperties {
    
    public let serverModels: [ServerModel]
    public let streamingResponse: VPNStreamingResponse?
    public let partnersResponse: VPNPartnersResponse?
    public let vpnCredentials: VpnCredentials?
    public let location: UserLocation?
    public let clientConfig: ClientConfig
    public let user: User?

    public init(serverModels: [ServerModel], vpnCredentials: VpnCredentials?, location: UserLocation?, clientConfig: ClientConfig?, streamingResponse: VPNStreamingResponse?, partnersResponse: VPNPartnersResponse?, user: User?) {
        self.serverModels = serverModels
        self.vpnCredentials = vpnCredentials
        self.location = location
        self.clientConfig = clientConfig ?? ClientConfig()
        self.streamingResponse = streamingResponse
        self.partnersResponse = partnersResponse
        self.user = user
    }
}
