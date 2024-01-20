import Foundation
import SubstrateSdk
import BigInt

struct Identity: Decodable {
    struct Registration: Decodable {
        let info: IdentityInfo
    }

    let info: IdentityInfo

    init(from decoder: Decoder) throws {
        do {
            var unkeyedContainer = try decoder.unkeyedContainer()

            info = try unkeyedContainer.decode(Registration.self).info
        } catch {
            // fallback to legacy identity

            info = try Registration(from: decoder).info
        }
    }
}

struct IdentityInfo: Decodable {
    let display: ChainData
    let legal: ChainData
    let web: ChainData
    let riot: ChainData?
    let matrix: ChainData?
    let email: ChainData
    let image: ChainData
    let twitter: ChainData

    func getMatrix() -> ChainData {
        riot ?? matrix ?? ChainData.none
    }
}
