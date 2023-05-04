import UIKit
import SoraFoundation
import RobinHood

final class ReferendumSearchInteractor: BaseReferendumsInteractor {
    weak var presenter: ReferendumSearchInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }

    let initialState: SearchReferendumsState
    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?
    private var currentSearchOperation: CancellableCall?

    init(
        initialState: SearchReferendumsState,
        selectedMetaAccount: MetaAccountModel,
        governanceState: GovernanceSharedState,
        chainRegistry: ChainRegistryProtocol,
        serviceFactory: GovernanceServiceFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        operationQueue: OperationQueue
    ) {
        self.initialState = initialState
        referendums = initialState.referendums
        referendumsMetadata = initialState.referendumsMetadata

        super.init(
            selectedMetaAccount: selectedMetaAccount,
            governanceState: governanceState,
            chainRegistry: chainRegistry,
            serviceFactory: serviceFactory,
            applicationHandler: applicationHandler,
            operationQueue: operationQueue
        )
    }

    override func setup() {
        initialState.blockNumber.map {
            presenter?.didReceiveBlockNumber($0)
        }
        initialState.blockTime.map {
            presenter?.didReceiveBlockTime($0)
        }
        initialState.referendumsMetadata.map { referendumsMetadata in
            presenter?.didReceiveReferendumsMetadata(referendumsMetadata)
        }
        initialState.referendums.map {
            updateReferendums($0)
        }
        initialState.offchainVoting.map {
            presenter?.didReceiveOffchainVoting($0)
        }
        initialState.voting.map {
            presenter?.didReceiveVoting($0)
        }
        initialState.chain.map {
            presenter?.didRecieveChain($0)
        }
        super.setup()
    }

    override func updateReferendums(_ referendums: [ReferendumLocal]) {
        self.referendums = referendums
        super.updateReferendums(referendums)
    }

    override func updateReferendumsMetadata(_ changes: [DataProviderChange<ReferendumMetadataLocal>]) {
        let indexedReferendums = Array((referendumsMetadata ?? [:]).values).reduceToDict()

        referendumsMetadata = changes.reduce(into: referendumsMetadata ?? [:]) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum[newItem.referendumId] = newItem
            case let .delete(deletedIdentifier):
                if let referendumId = indexedReferendums[deletedIdentifier]?.referendumId {
                    accum[referendumId] = nil
                }
            }
        }

        super.updateReferendumsMetadata(changes)
    }

    private func pointsForWord(title: String, word: String) -> UInt {
        if word.caseInsensitiveCompare(title) == .orderedSame {
            return 1000
        } else if title.range(of: word, options: .caseInsensitive) != nil {
            return 1
        } else {
            return 0
        }
    }

    private func pointsForPhrase(title: String, phrase: String) -> UInt {
        let pattern = phrase.replacingOccurrences(of: " ", with: ".*")
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return 0
        }
        let match = regex.firstMatch(
            in: title,
            range: NSRange(title.startIndex..., in: title)
        )
        return match != nil ? 1 : 0
    }

    private func searchOperation(text: String) -> BaseOperation<[ReferendumLocal]?> {
        ClosureOperation {
            guard let referendums = self.referendums else {
                return nil
            }
            guard !text.isEmpty else {
                return referendums
            }
            let calculatePoints = text.split(
                by: .space,
                maxSplits: 1
            ).count > 1 ? self.pointsForPhrase : self.pointsForWord
            let weights = referendums.reduce(into: [ReferendumIdLocal: UInt]()) { result, item in
                let title = self.referendumsMetadata?[item.index]?.title ?? "\(item.index)"
                result[item.index] = calculatePoints(title, text)
            }
            let searchedReferendums = referendums
                .filter {
                    weights[$0.index, default: 0] > 0
                }
                .sorted {
                    weights[$0.index, default: 0] > weights[$1.index, default: 0]
                }

            return searchedReferendums
        }
    }
}

extension ReferendumSearchInteractor: ReferendumSearchInteractorInputProtocol {
    func search(text: String) {
        currentSearchOperation?.cancel()

        let searchOperation = searchOperation(text: text)
        searchOperation.completionBlock = { [weak self] in
            do {
                let referendums = try searchOperation.extractNoCancellableResultData()
                DispatchQueue.main.async {
                    self?.presenter?.didReceiveReferendums(referendums ?? [])
                }
            } catch {
                self?.presenter?.didReceiveError(.searchFailed(text, error))
            }
        }

        currentSearchOperation = searchOperation

        operationQueue.addOperation(searchOperation)
    }
}
