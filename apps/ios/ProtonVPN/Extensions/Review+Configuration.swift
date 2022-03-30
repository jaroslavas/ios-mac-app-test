//
//  Created on 30.03.2022.
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

import vpncore
import Foundation
import Review

protocol ReviewFactory {
    func makeReview() -> Review
}

extension Configuration {
    init(settings: RatingSettings) {
        self.init(eligiblePlans: settings.eligiblePlans, successConnections: settings.successConnections, daysLastReviewPassed: settings.daysLastReviewPassed, daysConnected: settings.daysConnected, daysFromFirstConnection: settings.daysFromFirstConnection)
    }
}
