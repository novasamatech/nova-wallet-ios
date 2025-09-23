struct ReferendumsViewState: Equatable {
    var cells: [SecuredViewModel<ReferendumsCellViewModel>]
    var timeModels: [ReferendumIdLocal: StatusTimeViewModel?]?

    static func == (lhs: ReferendumsViewState, rhs: ReferendumsViewState) -> Bool {
        let lhsEquatableTuple: ([ReferendumsCellViewModel], [ViewPrivacyMode])
        let rhsEquatableTuple: ([ReferendumsCellViewModel], [ViewPrivacyMode])

        lhsEquatableTuple = lhs.cells.reduce(into: ([], [])) { acc, element in
            acc.0.append(element.originalContent)
            acc.1.append(element.privacyMode)
        }
        rhsEquatableTuple = lhs.cells.reduce(into: ([], [])) { acc, element in
            acc.0.append(element.originalContent)
            acc.1.append(element.privacyMode)
        }

        return lhsEquatableTuple == rhsEquatableTuple && lhs.timeModels == rhs.timeModels
    }
}
