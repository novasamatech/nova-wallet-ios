import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

enum Multisig {
    static var name: String { "Multisig" }

    struct PendingOperation: Codable, Equatable, Identifiable {
        var identifier: String {
            callHash.toHexString()
        }
        
        let call: JSON?
        let callHash: CallHash
        let multisigAccountId: AccountId
        let signatory: AccountId
        let chainId: ChainModel.Id
        let multisigDefinition: MultisigDefinition
    }

    struct MultisigDefinition: Codable, Equatable {
        enum CodingKeys: String, CodingKey {
            case timepoint = "when"
            case depositor
            case approvals
        }

        let timepoint: MultisigTimepoint
        @BytesCodable var depositor: AccountId
        var approvals: [BytesCodable]
    }

    struct MultisigTimepoint: Codable, Equatable {
        @StringCodable var height: BlockNumber
        @StringCodable var index: UInt32
    }
}

extension Multisig.PendingOperation {
    func replaicingDefinition(with definition: Multisig.MultisigDefinition) -> Self {
        .init(
            call: call,
            callHash: callHash,
            multisigAccountId: multisigAccountId,
            signatory: signatory,
            chainId: chainId,
            multisigDefinition: definition
        )
    }
}
