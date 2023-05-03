import UIKit
import SoraFoundation
import RobinHood

final class ReferendumSearchInteractor: BaseReferendumsInteractor {
    weak var presenter: ReferendumSearchInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }

    let initialState: SearchReferndumsInitialState
    private var referendums: [ReferendumLocal]?
    private var referendumsMetadata: ReferendumMetadataMapping?

    init(
        initialState: SearchReferndumsInitialState,
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
}

extension ReferendumSearchInteractor: ReferendumSearchInteractorInputProtocol {
    func search(text: String) {
        print(text)
        guard let referendums = referendums else {
            return
        }

        let weightFunction: (String, String) -> UInt = text.split(by: .space).count > 1 ? phraseWeight : singleWeight
        let weights = referendums.reduce(into: [ReferendumIdLocal: UInt]()) {
            $0[$1.index] = weightFunction(
                text.lowercased(),
                (referendumsMetadata?[$1.index]?.title ?? "\($1.index)").lowercased()
            )
        }
        let searchedReferendums = referendums.filter {
            (weights[$0.index] ?? 0) > 0
        }.sorted(by: { (weights[$0.index] ?? 0) > (weights[$1.index] ?? 0) })

        presenter?.didReceiveReferendums(searchedReferendums)
    }

    func singleWeight(word: String, title: String) -> UInt {
        if word == title {
            return 1000
        } else if title.contains(word) {
            return 1
        } else {
            return 0
        }
    }

    func phraseWeight(phrase: String, title: String) -> UInt {
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
}
