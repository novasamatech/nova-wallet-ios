import SubstrateSdk
import Operation_iOS

extension Multisig {
    struct PendingOperation: Codable {
        let call: Substrate.CallData?
        let callHash: Substrate.CallHash
        let timestamp: UInt64
        let multisigAccountId: AccountId
        let signatory: AccountId
        let chainId: ChainModel.Id
        let multisigDefinition: MultisigDefinition?

        func isCreator(accountId: AccountId) -> Bool {
            multisigDefinition?.depositor == accountId
        }
    }

    struct MultisigDefinition: Codable, Equatable {
        let timepoint: MultisigTimepoint
        let depositor: AccountId
        let approvals: [AccountId]

        init(
            timepoint: MultisigTimepoint,
            depositor: AccountId,
            approvals: [AccountId]
        ) {
            self.timepoint = timepoint
            self.depositor = depositor
            self.approvals = approvals
        }

        init(from onChainModel: MultisigPallet.MultisigDefinition) {
            timepoint = .init(
                height: onChainModel.timepoint.height,
                index: onChainModel.timepoint.index
            )
            depositor = onChainModel.depositor
            approvals = onChainModel.approvals.map(\.wrappedValue)
        }
    }

    struct MultisigTimepoint: Codable, Hashable {
        let height: BlockNumber
        let index: UInt32
    }
}

extension Multisig.MultisigTimepoint {
    func toSubmissionModel() -> MultisigPallet.MultisigTimepoint {
        .init(height: height, index: index)
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
        let callHash: Substrate.CallHash
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
    func updating(with operation: Multisig.PendingOperation) -> Self {
        var updatedValue = self

        updatedValue = updatedValue
            .replacingDefinition(with: operation.multisigDefinition)
            .replacingTimestamp(with: operation.timestamp)

        if let callUpdate = operation.call, call == nil {
            updatedValue = updatedValue.replacingCall(with: callUpdate)
        }

        return updatedValue
    }

    func replacingDefinition(with definition: Multisig.MultisigDefinition?) -> Self {
        .init(
            call: call,
            callHash: callHash,
            timestamp: timestamp,
            multisigAccountId: multisigAccountId,
            signatory: signatory,
            chainId: chainId,
            multisigDefinition: definition
        )
    }

    func replacingCall(with newCall: Substrate.CallData?) -> Self {
        .init(
            call: newCall,
            callHash: callHash,
            timestamp: timestamp,
            multisigAccountId: multisigAccountId,
            signatory: signatory,
            chainId: chainId,
            multisigDefinition: multisigDefinition
        )
    }

    func replacingTimestamp(with newTimestamp: UInt64) -> Self {
        .init(
            call: call,
            callHash: callHash,
            timestamp: newTimestamp,
            multisigAccountId: multisigAccountId,
            signatory: signatory,
            chainId: chainId,
            multisigDefinition: multisigDefinition
        )
    }
}
