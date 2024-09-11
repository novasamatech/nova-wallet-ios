struct ReferendumsViewState: Equatable {
    var cells: [ReferendumsCellViewModel]
    var timeModels: [ReferendumIdLocal: StatusTimeViewModel?]?
}
