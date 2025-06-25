import SubstrateSdk
import Operation_iOS

extension Multisig {
    struct PendingOperation: Codable {
        let call: JSON?
        let callHash: CallHash
        let multisigAccountId: AccountId
        let signatory: AccountId
        let chainId: ChainModel.Id
        let multisigDefinition: MultisigDefinition?
    }

    struct MultisigDefinition: Codable, Equatable {
        let timepoint: MultisigTimepoint
        let depositor: AccountId
        let approvals: [AccountId]
        
        init(from onChainModel: MultisigPallet.MultisigDefinition) {
            timepoint = .init(
                height: onChainModel.timepoint.height,
                index: onChainModel.timepoint.index
            )
            depositor = onChainModel.depositor
            approvals = onChainModel.approvals.map(\.wrappedValue)
        }
    }

    struct MultisigTimepoint: Codable, Equatable {
        let height: BlockNumber
        let index: UInt32
    }
}

// MARK: - Identifiable

extension Multisig.PendingOperation: Identifiable {
    var identifier: String {
        createKey().stringValue()
    }
}

// MARK: - Key

extension Multisig.PendingOperation {
    struct Key: Hashable {
        let callHash: CallHash
        let chainId: ChainModel.Id
        let multisigAccountId: AccountId
        let signatoryAccountId: AccountId

        func stringValue() -> String {
            [
                callHash.toHexString(),
                chainId,
                multisigAccountId.toHexString(),
                signatoryAccountId.toHexString()
            ].joined(with: .slash)
        }
    }

    func createKey() -> Key {
        Key(
            callHash: callHash,
            chainId: chainId,
            multisigAccountId: multisigAccountId,
            signatoryAccountId: signatory
        )
    }
}

// MARK: - Update Helpers

extension Multisig.PendingOperation {
    func replacingDefinition(with definition: Multisig.MultisigDefinition?) -> Self {
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
