import Foundation
import Operation_iOS

protocol SwipeGovModelBuilderProtocol {
    func apply(_ referendumsState: ReferendumsState)
    func apply(
        votingsChanges: [DataProviderChange<VotingBasketItemLocal>],
        _ referendumsState: ReferendumsState
    )
}

final class SwipeGovModelBuilder {
    var referendums: [ReferendumIdLocal: ReferendumLocal] = [:]

    private let sorting: ReferendumsSorting
    private let workingQueue: OperationQueue
    private let callbackQueue: DispatchQueue
    private let closure: (Result) -> Void

    private var votingList: [VotingBasketItemLocal] = []

    private var currentModel: Result.Model = .init()

    init(
        sorting: ReferendumsSorting,
        workingQueue: OperationQueue,
        callbackQueue: DispatchQueue = .main,
        closure: @escaping (Result) -> Void
    ) {
        self.sorting = sorting
        self.workingQueue = workingQueue
        self.callbackQueue = callbackQueue
        self.closure = closure
    }
}

// MARK: SwipeGovModelBuilderProtocol

extension SwipeGovModelBuilder: SwipeGovModelBuilderProtocol {
    func apply(_ referendumsState: ReferendumsState) {
        workingQueue.addOperation { [weak self] in
            guard let self else { return }

            let filteredReferendums = filteredReferendums(from: referendumsState)
            let changes = createReferendumsChange(from: filteredReferendums)

            referendums = filteredReferendums

            rebuild(
                with: changes,
                changeKind: .referendums
            )
        }
    }

    func apply(
        votingsChanges: [DataProviderChange<VotingBasketItemLocal>],
        _ referendumsState: ReferendumsState
    ) {
        workingQueue.addOperation { [weak self] in
            guard let self else { return }

            votingList = votingList.applying(changes: votingsChanges)

            let filteredReferendums = filteredReferendums(from: referendumsState)
            let changes = createReferendumsChange(from: filteredReferendums)

            self.referendums = filteredReferendums

            rebuild(
                with: changes,
                changeKind: .full
            )
        }
    }
}

// MARK: Private

private extension SwipeGovModelBuilder {
    func rebuild(
        with changes: Result.ReferendumsListChanges,
        changeKind: Result.ChangeKind
    ) {
        let model = Result.Model(
            referendums: sorted(Array(referendums.values)),
            referendumsChanges: changes,
            votingList: votingList
        )

        currentModel = model

        let result = Result(
            model: model,
            changeKind: changeKind
        )

        callbackQueue.async { [weak self] in self?.closure(result) }
    }

    func createReferendumsChange(
        from referendums: [ReferendumIdLocal: ReferendumLocal]
    ) -> Result.ReferendumsListChanges {
        var referendumsToChange = referendums

        votingList.forEach { referendumsToChange.removeValue(forKey: $0.referendumId) }

        return findReferendumChanges(for: referendumsToChange)
    }

    func findReferendumChanges(
        for newReferendums: [ReferendumIdLocal: ReferendumLocal]
    ) -> Result.ReferendumsListChanges {
        var inserts: [ReferendumLocal] = []
        var updates: [ReferendumLocal] = []
        var deletes: [ReferendumIdLocal] = []

        newReferendums.forEach { key, value in
            if self.referendums[key] == nil {
                inserts.append(value)
            } else {
                updates.append(value)
            }
        }

        referendums.forEach { key, value in
            if newReferendums[key] == nil {
                deletes.append(value.index)
            }
        }

        return Result.ReferendumsListChanges(
            inserts: sorted(inserts),
            updates: updates,
            deletes: deletes
        )
    }

    func sorted(_ referendums: [ReferendumLocal]) -> [ReferendumLocal] {
        referendums.sorted {
            sorting.compare(
                referendum1: $0,
                referendum2: $1
            )
        }
    }

    func filteredReferendums(from referendumsState: ReferendumsState) -> [ReferendumIdLocal: ReferendumLocal] {
        ReferendumFilter.VoteAvailable(
            referendums: referendumsState.referendums,
            accountVotes: referendumsState.voting?.value?.votes
        ).callAsFunction()
    }
}

// MARK: Model

extension SwipeGovModelBuilder {
    struct Result {
        struct Model {
            let referendums: [ReferendumLocal]
            let referendumsChanges: ReferendumsListChanges
            let votingList: [VotingBasketItemLocal]

            init(
                referendums: [ReferendumLocal] = [],
                referendumsChanges: ReferendumsListChanges = .init(inserts: [], updates: [], deletes: []),
                votingList: [VotingBasketItemLocal] = []
            ) {
                self.referendums = referendums
                self.referendumsChanges = referendumsChanges
                self.votingList = votingList
            }

            func replacing(_ votingList: [VotingBasketItemLocal]) -> Self {
                .init(
                    referendums: referendums,
                    referendumsChanges: referendumsChanges,
                    votingList: votingList
                )
            }
        }

        struct ReferendumsListChanges {
            let inserts: [ReferendumLocal]
            let updates: [ReferendumLocal]
            let deletes: [ReferendumIdLocal]
        }

        enum ChangeKind {
            case referendums
            case full
        }

        let model: Model
        let changeKind: ChangeKind
    }
}
