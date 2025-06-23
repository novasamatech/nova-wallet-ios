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
            eventType = .newMultisig
        } else if let approvalEvent = try? params.map(
            to: MultisigPallet.MultisigApprovalEvent.self,
            with: context
        ) {
            accountId = approvalEvent.accountId
            callHash = approvalEvent.callHash
            eventType = .approval
        } else {
            return nil
        }
    }
}

extension MultisigEvent {
    enum EventType {
        case newMultisig
        case approval
    }
}
