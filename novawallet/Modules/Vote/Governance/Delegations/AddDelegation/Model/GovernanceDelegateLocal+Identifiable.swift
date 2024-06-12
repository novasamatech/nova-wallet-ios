import Operation_iOS

extension GovernanceDelegateLocal: Identifiable {
    var identifier: String {
        stats.address
    }
}
