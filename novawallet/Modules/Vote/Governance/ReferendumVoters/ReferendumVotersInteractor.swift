import UIKit
import SubstrateSdk
import RobinHood

final class ReferendumVotersInteractor {
    weak var presenter: ReferendumVotersInteractorOutputProtocol?

    let referendumsOperationFactory: ReferendumsOperationFactoryProtocol
    let chain: ChainModel
    let referendumIndex: Referenda.ReferendumIndex
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    init(
        referendumIndex: Referenda.ReferendumIndex,
        chain: ChainModel,
        referendumsOperationFactory: ReferendumsOperationFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.referendumIndex = referendumIndex
        self.chain = chain
        self.referendumsOperationFactory = referendumsOperationFactory
        self.identityOperationFactory = identityOperationFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    private func provideVoters() {
        let voterWrapper = referendumsOperationFactory.fetchVotersWrapper(
            for: referendumIndex,
            from: connection,
            runtimeProvider: runtimeProvider
        )

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: {
                let voters = try voterWrapper.targetOperation.extractNoCancellableResultData()
                return voters.map(\.accountId)
            },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chain.chainFormat
        )

        identityWrapper.addDependency(wrapper: voterWrapper)

        let mappingOperation = ClosureOperation<ReferendumVotersModel> {
            let voters = try voterWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()

            return ReferendumVotersModel(voters: voters, identites: identities)
        }

        mappingOperation.addDependency(identityWrapper.targetOperation)

        mappingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try mappingOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveVoters(model)
                } catch {
                    self?.presenter?.didReceiveError(.votersFetchFailed(error))
                }
            }
        }

        let operations = voterWrapper.allOperations + identityWrapper.allOperations + [mappingOperation]

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }
}

extension ReferendumVotersInteractor: ReferendumVotersInteractorInputProtocol {
    func setup() {
        provideVoters()
    }

    func refreshVoters() {
        provideVoters()
    }
}
