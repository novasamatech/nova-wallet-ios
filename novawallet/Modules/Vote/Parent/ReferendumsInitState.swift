final class ReferendumsInitState {
    let referendumIndex: Referenda.ReferendumIndex
    let stateHandledClosure: () -> Void

    init(referendumIndex: Referenda.ReferendumIndex, stateHandledClosure: @escaping () -> Void) {
        self.referendumIndex = referendumIndex
        self.stateHandledClosure = stateHandledClosure
    }
}
