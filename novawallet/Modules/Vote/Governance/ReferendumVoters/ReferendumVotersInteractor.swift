import UIKit
import SubstrateSdk
import Operation_iOS

final class ReferendumVotersInteractor {
    weak var presenter: ReferendumVotersInteractorOutputProtocol?

    let referendumsOperationFactory: ReferendumsOperationFactoryProtocol
    let votersLocalWrapperFactory: ReferendumVotersLocalWrapperFactoryProtocol?
    let chain: ChainModel
    let votersType: ReferendumVotersType
    let referendumIndex: ReferendumIdLocal
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    private var abstainsFetchCancellable = CancellableCallStore()

    init(
        referendumIndex: ReferendumIdLocal,
        chain: ChainModel,
        votersType: ReferendumVotersType,
        referendumsOperationFactory: ReferendumsOperationFactoryProtocol,
        votersLocalWrapperFactory: ReferendumVotersLocalWrapperFactoryProtocol?,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.referendumIndex = referendumIndex
        self.chain = chain
        self.votersType = votersType
        self.referendumsOperationFactory = referendumsOperationFactory
        self.votersLocalWrapperFactory = votersLocalWrapperFactory
        self.identityProxyFactory = identityProxyFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    // MARK: Provide

    private func provideVoters() {
        switch votersType {
        case .ayes, .nays:
            provideStandardVoters()
        case .abstains:
            provideAbstainVoters()
        }
    }

    private func provideStandardVoters() {
        let wrapper = createStandardVotesFetchWrapper()

        executeWrapper(wrapper)
    }

    private func provideAbstainVoters() {
        abstainsFetchCancellable.cancel()

        let wrapper = createAbstainsFetchWrapper()

        abstainsFetchCancellable.store(call: wrapper)
        executeWrapper(wrapper)
    }

    // MARK: - Wrappers

    private func createAbstainsFetchWrapper() -> CompoundOperationWrapper<ReferendumVotersModel> {
        guard let votersLocalWrapperFactory else {
            return .createWithError(NSError())
        }
        let voterWrapper = votersLocalWrapperFactory.createWrapper(
            for: .init(referendumId: referendumIndex, votersType: .abstains)
        )

        let mappingOperation = ClosureOperation<ReferendumVotersModel> { [weak self] in
            let voters = try voterWrapper.targetOperation.extractNoCancellableResultData()

            let identities = try voters
                .identities
                .reduce(into: [AccountAddress: AccountIdentity]()) { acc, element in
                    guard let chainFormat = self?.chain.chainFormat else {
                        return
                    }

                    let address = try element.key.toAddress(using: chainFormat)
                    acc[address] = element.value
                }

            return ReferendumVotersModel(voters: voters.model, identites: identities)
        }

        mappingOperation.addDependency(voterWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: voterWrapper.allOperations
        )
    }

    private func createStandardVotesFetchWrapper() -> CompoundOperationWrapper<ReferendumVotersModel> {
        let voterWrapper = referendumsOperationFactory.fetchVotersWrapper(
            for: referendumIndex,
            from: connection,
            runtimeProvider: runtimeProvider
        )

        let identityWrapper = identityProxyFactory.createIdentityWrapper(
            for: {
                let voters = try voterWrapper.targetOperation.extractNoCancellableResultData()
                return voters.map(\.accountId)
            }
        )

        identityWrapper.addDependency(wrapper: voterWrapper)

        let mappingOperation = ClosureOperation<ReferendumVotersModel> {
            let voters = try voterWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()

            return ReferendumVotersModel(voters: voters, identites: identities)
        }

        mappingOperation.addDependency(identityWrapper.targetOperation)

        let operations = voterWrapper.allOperations + identityWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: operations
        )
    }

    private func executeWrapper(_ wrapper: CompoundOperationWrapper<ReferendumVotersModel>) {
        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.abstainsFetchCancellable.clear()

            switch result {
            case let .success(model):
                self?.presenter?.didReceiveVoters(model)
            case let .failure(error):
                self?.presenter?.didReceiveError(.votersFetchFailed(error))
            }
        }
    }
}

// MARK: - ReferendumVotersInteractorInputProtocol

extension ReferendumVotersInteractor: ReferendumVotersInteractorInputProtocol {
    func setup() {
        provideVoters()
    }

    func refreshVoters() {
        provideVoters()
    }
}
