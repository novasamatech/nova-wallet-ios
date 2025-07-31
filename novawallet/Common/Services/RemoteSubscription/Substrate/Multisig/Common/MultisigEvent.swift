import SubstrateSdk

struct MultisigEvent: Hashable {
    let accountId: AccountId
    let callHash: Substrate.CallHash
    let extrinsicIndex: UInt32
    let eventType: EventType

    init(
        accountId: AccountId,
        callHash: Substrate.CallHash,
        extrinsicIndex: UInt32,
        eventType: EventType
    ) {
        self.accountId = accountId
        self.callHash = callHash
        self.extrinsicIndex = extrinsicIndex
        self.eventType = eventType
    }

    init?(
        params: JSON,
        extrinsicIndex: UInt32,
        context: [CodingUserInfoKey: Any]
    ) {
        self.extrinsicIndex = extrinsicIndex

        if let newMultisigEvent = try? params.map(
            to: MultisigPallet.NewMultisigEvent.self,
            with: context
        ) {
            accountId = newMultisigEvent.accountId
            callHash = newMultisigEvent.callHash

            let model = NewMultisig(signatory: newMultisigEvent.approvingAccountId)
            eventType = .newMultisig(model)
        } else if let approvalEvent = try? params.map(
            to: MultisigPallet.MultisigApprovalEvent.self,
            with: context
        ) {
            accountId = approvalEvent.accountId
            callHash = approvalEvent.callHash

            let model = Approval(
                signatory: approvalEvent.approvingAccountId,
                timepoint: approvalEvent.timepoint
            )
            eventType = .approval(model)
        } else {
            return nil
        }
    }
}

extension MultisigEvent {
    var signatory: AccountId {
        switch eventType {
        case let .newMultisig(model):
            model.signatory
        case let .approval(model):
            model.signatory
        }
    }

    enum EventType: Hashable {
        case newMultisig(NewMultisig)
        case approval(Approval)
    }

    struct NewMultisig: Hashable {
        let signatory: AccountId
    }

    struct Approval: Hashable {
        let signatory: AccountId
        let timepoint: MultisigPallet.EventTimePoint
    }
}
