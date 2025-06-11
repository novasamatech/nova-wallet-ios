import Foundation
import SubstrateSdk
import BigInt

enum Multisig {
    static var name: String { "Multisig" }

    struct PendingOperation: Codable, Equatable {
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
