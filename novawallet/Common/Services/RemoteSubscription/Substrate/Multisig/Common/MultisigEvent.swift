import SubstrateSdk

struct MultisigEvent: Hashable {
    let accountId: AccountId
    let callHash: CallHash
    let eventType: EventType

    init?(
        params: JSON,
        context: [CodingUserInfoKey: Any]
    ) {
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
            
            let timepoint = Multisig.MultisigTimepoint(
                height: approvalEvent.timepoint.height,
                index: approvalEvent.timepoint.index
            )
            let model = Approval(
                signatory: approvalEvent.approvingAccountId,
                timepoint: timepoint
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
        let timepoint: Multisig.MultisigTimepoint
    }
}
