import Foundation
import Operation_iOS

protocol SwipeGovModelBuilderProtocol {
    func apply(_ referendumsState: ReferendumsState)
    func apply(votingsChanges: [DataProviderChange<VotingBasketItemLocal>])
    func applyEligible(referendums: Set<ReferendumIdLocal>)
}

final class SwipeGovModelBuilder {
    private let sorting: ReferendumsSorting
    private let workingQueue: OperationQueue
    private let callbackQueue: DispatchQueue
    private let closure: (Result) -> Void

    private var referendumsStateStore: UncertainStorage<ReferendumsState> = .undefined
    private var votingListStore: UncertainStorage<[VotingBasketItemLocal]> = .undefined
    private var eligibleReferendumsStore: UncertainStorage<Set<ReferendumIdLocal>> = .undefined
    private var lastSeenReferendums: [ReferendumIdLocal: ReferendumLocal] = [:]

    init(
        sorting: ReferendumsSorting,
        callbackQueue: DispatchQueue = .main,
        closure: @escaping (Result) -> Void
    ) {
        self.sorting = sorting

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        workingQueue = operationQueue

        self.callbackQueue = callbackQueue
        self.closure = closure
    }
}

// MARK: SwipeGovModelBuilderProtocol

extension SwipeGovModelBuilder: SwipeGovModelBuilderProtocol {
    func apply(_ referendumsState: ReferendumsState) {
        workingQueue.addOperation { [weak self] in
            guard let self else { return }

            referendumsStateStore = .defined(referendumsState)

            rebuild()
        }
    }

    func apply(votingsChanges: [DataProviderChange<VotingBasketItemLocal>]) {
        workingQueue.addOperation { [weak self] in
            guard let self else { return }

            switch votingListStore {
            case let .defined(votingList):
                let newList = votingList.applying(changes: votingsChanges)
                votingListStore = .defined(newList)
            case .undefined:
                let newList = [].applying(changes: votingsChanges)
                votingListStore = .defined(newList)
            }

            rebuild()
        }
    }

    func applyEligible(referendums: Set<ReferendumIdLocal>) {
        workingQueue.addOperation { [weak self] in
            guard let self else { return }

            eligibleReferendumsStore = .defined(referendums)

            rebuild()
        }
    }
}

// MARK: Private

private extension SwipeGovModelBuilder {
    func rebuild() {
        guard
            case let .defined(referendumsState) = referendumsStateStore,
            case let .defined(votingList) = votingListStore,
            case let .defined(eligibleReferendums) = eligibleReferendumsStore else {
            return
        }

        let filteredReferendums = filteredReferendums(
            from: referendumsState,
            eligibleReferendums: eligibleReferendums,
            votingList: votingList
        )

        let changes = findReferendumChanges(for: filteredReferendums, prevReferendums: lastSeenReferendums)

        lastSeenReferendums = filteredReferendums

        let model = Result.Model(
            referendums: sorted(Array(filteredReferendums.values)),
            referendumsChanges: changes,
            votingList: votingList
        )

        let result = Result(model: model)

        callbackQueue.async { [weak self] in self?.closure(result) }
    }

    func findReferendumChanges(
        for newReferendums: [ReferendumIdLocal: ReferendumLocal],
        prevReferendums: [ReferendumIdLocal: ReferendumLocal]
    ) -> Result.ReferendumsListChanges {
        var inserts: [ReferendumLocal] = []
        var updates: [ReferendumLocal] = []
        var deletes: [ReferendumIdLocal] = []

        newReferendums.forEach { key, value in
            if prevReferendums[key] == nil {
                inserts.append(value)
            } else {
                updates.append(value)
            }
        }

        prevReferendums.forEach { key, value in
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
        referendums.sorted { sorting.compare(referendum1: $0, referendum2: $1) }
    }

    func filteredReferendums(
        from referendumsState: ReferendumsState,
        eligibleReferendums: Set<ReferendumIdLocal>,
        votingList: [VotingBasketItemLocal]
    ) -> [ReferendumIdLocal: ReferendumLocal] {
        let remoteFiltered = ReferendumFilter.EligibleForSwipeGov(
            referendums: referendumsState.referendums,
            accountVotes: referendumsState.voting?.value?.votes,
            elegibleReferendums: eligibleReferendums
        ).callAsFunction()

        let votingListIds = Set(votingList.map(\.referendumId))

        return remoteFiltered.filter { !votingListIds.contains($0.key) }
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

        let model: Model
    }
}
