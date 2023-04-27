extension ReferendumsFilter {
    func match(_ referendum: ReferendumLocal) -> Bool {
        switch self {
        case .all:
            return true
        case .notVoted:
            return referendum.voting == nil
        case .voted:
            return referendum.voting != nil
        }
    }
}
