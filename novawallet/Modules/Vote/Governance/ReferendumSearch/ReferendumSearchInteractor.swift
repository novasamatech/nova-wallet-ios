import UIKit
import SoraFoundation

final class ReferendumSearchInteractor: BaseReferendumsInteractor {
    weak var presenter: ReferendumSearchInteractorOutputProtocol?
    let initialState: SearchReferndumsInitialState

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
//        initialState.referendumsMetadata.map { metadata in
//            presenter?.didReceiveReferendumsMetadata(metadata.map { .insert(newItem: $0) })
//        }
        initialState.referendums.map {
            presenter?.didReceiveReferendums($0)
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
}

extension ReferendumSearchInteractor: ReferendumSearchInteractorInputProtocol {}
