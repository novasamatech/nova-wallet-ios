struct ReferendumsViewState: Equatable {
    var cells: [ReferendumsCellViewModel]
    var timeModels: [ReferendumIdLocal: StatusTimeViewModel?]?
}

struct ReferendumsState {
    let referendums: [ReferendumIdLocal: ReferendumLocal]
    let accountVotes: ReferendumAccountVotingDistribution?

    init(
        referendums: [ReferendumIdLocal: ReferendumLocal] = [:],
        accountVotes: ReferendumAccountVotingDistribution? = nil
    ) {
        self.referendums = referendums
        self.accountVotes = accountVotes
    }
}
