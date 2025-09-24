struct ReferendumsViewState: Equatable {
    var cells: [SecuredViewModel<ReferendumsCellViewModel>]
    var timeModels: [ReferendumIdLocal: StatusTimeViewModel?]?
}
