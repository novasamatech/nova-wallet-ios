struct ReferendumsState: Equatable {
    var cells: [ReferendumsCellViewModel]
    var timeModels: [ReferendumIdLocal: StatusTimeViewModel?]?
}
