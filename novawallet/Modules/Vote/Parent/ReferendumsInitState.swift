final class ReferendumsInitState {
    let referendumIndex: Referenda.ReferendumIndex
    let completionHandler: () -> Void

    init(referendumIndex: Referenda.ReferendumIndex, completionHandler: @escaping () -> Void) {
        self.referendumIndex = referendumIndex
        self.completionHandler = completionHandler
    }
}
