import Foundation
import Operation_iOS

final class TinderGovModelBuilder {
    private let sorting: ReferendumsSorting
    private let workingQueue: OperationQueue
    private let callbackQueue: DispatchQueue
    private let closure: (Result) -> Void

    private var referendums: [ReferendumIdLocal: ReferendumLocal] = [:]
    private var votingList: [ReferendumIdLocal] = []

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

extension TinderGovModelBuilder {
    func apply(_ newReferendums: [ReferendumIdLocal: ReferendumLocal]) {
        workingQueue.addOperation { [weak self] in
            guard let self else { return }

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

            let changes = Result.ReferendumsListChanges(
                inserts: sorted(inserts),
                updates: updates,
                deletes: deletes
            )

            referendums = newReferendums

            rebuild(with: sorted(Array(newReferendums.values)), changes)
        }
    }

    func apply(voting: ReferendumIdLocal) {
        workingQueue.addOperation { [weak self] in
            self?.votingList.append(voting)
            self?.rebuildVotingList()
        }
    }

    func apply(votings: [ReferendumIdLocal]) {
        workingQueue.addOperation { [weak self] in
            votings.forEach { self?.votingList.append($0) }
            self?.rebuildVotingList()
        }
    }

    func buildOnSetup() {
        let result = Result(
            model: currentModel,
            changeKind: .setup
        )

        callbackQueue.async { [weak self] in self?.closure(result) }
    }
}

// MARK: Private

private extension TinderGovModelBuilder {
    func rebuild(
        with referendums: [ReferendumLocal],
        _ changes: Result.ReferendumsListChanges
    ) {
        let model = Result.Model(
            referendums: referendums,
            referendumsChanges: changes,
            votingList: votingList
        )

        currentModel = model

        let result = Result(
            model: model,
            changeKind: .referendums
        )

        callbackQueue.async { [weak self] in self?.closure(result) }
    }

    func rebuildVotingList() {
        let model = currentModel.replacing(votingList)

        currentModel = model

        let result = Result(
            model: model,
            changeKind: .votingList
        )

        callbackQueue.async { [weak self] in self?.closure(result) }
    }

    func sorted(_ referendums: [ReferendumLocal]) -> [ReferendumLocal] {
        referendums.sorted {
            sorting.compare(
                referendum1: $0,
                referendum2: $1
            )
        }
    }
}

// MARK: Model

extension TinderGovModelBuilder {
    struct Result {
        struct Model {
            let referendums: [ReferendumLocal]
            let referendumsChanges: ReferendumsListChanges
            let votingList: [ReferendumIdLocal]

            init(
                referendums: [ReferendumLocal] = [],
                referendumsChanges: ReferendumsListChanges = .init(inserts: [], updates: [], deletes: []),
                votingList: [ReferendumIdLocal] = []
            ) {
                self.referendums = referendums
                self.referendumsChanges = referendumsChanges
                self.votingList = votingList
            }

            func replacing(_ votingList: [ReferendumIdLocal]) -> Self {
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
            case votingList
            case setup
        }

        let model: Model
        let changeKind: ChangeKind
    }
}
