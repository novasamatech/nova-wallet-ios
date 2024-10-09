enum PayCardStatus: String, Equatable {
    case pending
    case created
    case failed

    var isCreated: Bool {
        switch self {
        case .pending, .failed:
            false
        case .created:
            true
        }
    }
}
