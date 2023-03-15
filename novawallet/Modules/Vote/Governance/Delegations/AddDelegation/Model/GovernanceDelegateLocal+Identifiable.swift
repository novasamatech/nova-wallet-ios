import RobinHood

extension GovernanceDelegateLocal: Identifiable {
    var identifier: String {
        stats.address
    }
}
