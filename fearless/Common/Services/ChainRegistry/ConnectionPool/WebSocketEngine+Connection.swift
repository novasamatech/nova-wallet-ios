import Foundation
import SubstrateSdk

extension WebSocketEngine: ConnectionAutobalancing {
    var ranking: [ConnectionRank] {
        // TODO: FWL-1153
        []
    }

    func set(ranking _: [ConnectionRank]) {
        // TODO: FWL-1153
    }
}

extension WebSocketEngine: ConnectionStateReporting {}
