typealias ReferendumsObservableState = Observable<NotEqualWrapper<ReferendumsState>>

struct ReferendumsState {
    let referendums: [ReferendumIdLocal: ReferendumLocal]
    let voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?

    init(
        referendums: [ReferendumIdLocal: ReferendumLocal] = [:],
        voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>? = nil
    ) {
        self.referendums = referendums
        self.voting = voting
    }
}

extension ReferendumsObservableState {
    var value: ReferendumsState {
        state.value
    }

    var referendums: [ReferendumIdLocal: ReferendumLocal] {
        state.value.referendums
    }

    var voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>? {
        state.value.voting
    }

    func update(with referendums: [ReferendumIdLocal: ReferendumLocal]) {
        let newState = ReferendumsState(
            referendums: referendums,
            voting: state.value.voting
        )

        state = .init(value: newState)
    }

    func update(with voting: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        let newState = ReferendumsState(
            referendums: state.value.referendums,
            voting: voting
        )

        state = .init(value: newState)
    }
}

extension Dictionary where Key == ReferendumIdLocal, Value == ReferendumLocal {
    init(from array: [ReferendumLocal]) {
        self = array.reduce(into: [:]) { $0[$1.index] = $1 }
    }
}
