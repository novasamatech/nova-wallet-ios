import Foundation
import SubstrateSdk

struct XcmAssetsLocation: Decodable {
    let store: [String: JSON]

    func rawLocation(for key: String) -> JSON? {
        store[key]
    }
}
