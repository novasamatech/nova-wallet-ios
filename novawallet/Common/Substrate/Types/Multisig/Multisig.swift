import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

enum Multisig {
    static var name: String { "Multisig" }

    struct PendingOperation: Codable, Equatable, Identifiable {
        var identifier: String {
            createKey().stringValue()
        }

        struct Key: Hashable {
            let callHash: CallHash
            let chainId: ChainModel.Id
            let multisigAccountId: AccountId

            func stringValue() -> String {
                [
                    callHash.toHexString(),
                    chainId,
                    multisigAccountId.toHexString()
                ].joined(with: .slash)
            }
        }

        let call: JSON?
        let callHash: CallHash
        let multisigAccountId: AccountId
        let signatory: AccountId
        let chainId: ChainModel.Id
        let multisigDefinition: MultisigDefinition

        func createKey() -> Key {
            Key(
                callHash: callHash,
                chainId: chainId,
                multisigAccountId: multisigAccountId
            )
        }
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

    func replacingCall(with newCall: JSON?) -> Self {
        .init(
            call: newCall,
            callHash: callHash,
            multisigAccountId: multisigAccountId,
            signatory: signatory,
            chainId: chainId,
            multisigDefinition: multisigDefinition
        )
    }
}

struct CallHashKey: JSONListConvertible, Hashable {
    let accountId: AccountId
    let callHash: CallHash

    init(
        accountId: AccountId,
        callHash: CallHash
    ) {
        self.accountId = accountId
        self.callHash = callHash
    }

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        let expectedFieldsCount = 2
        let actualFieldsCount = jsonList.count
        guard expectedFieldsCount == actualFieldsCount else {
            throw JSONListConvertibleError.unexpectedNumberOfItems(
                expected: expectedFieldsCount,
                actual: actualFieldsCount
            )
        }

        accountId = try jsonList[0].map(to: AccountId.self, with: context)
        callHash = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
    }
}
