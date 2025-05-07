import Foundation
import SubstrateSdk
import BigInt

enum Multisig {
    static var name: String { "Multisig" }

    struct MultisigOperation: Codable, Equatable {
        enum CodingKeys: String, CodingKey {
            case timepoint = "when"
            case deposit
            case depositor
            case approvals
        }

        let timepoint: MultisigTimepoint
        let deposit: BigUInt
        @BytesCodable var depositor: AccountId
        var approvals: [BytesCodable]
    }

    struct MultisigTimepoint: Codable, Equatable {
        let height: BlockNumber
        let index: UInt32
    }
}
