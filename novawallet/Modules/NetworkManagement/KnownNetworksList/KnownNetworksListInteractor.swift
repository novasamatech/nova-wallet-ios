import UIKit
import Operation_iOS

final class KnownNetworksListInteractor {
    weak var presenter: KnownNetworksListInteractorOutputProtocol?
    
    private let lightChainsFetchFactory: LightChainsFetchFactoryProtocol
    private let preConfiguredChainFetchFactory: PreConfiguredChainFetchFactoryProtocol
    
    private let operationQueue: OperationQueue
    
    private var lightChains: [LightChainModel] = []
    
    init(
        lightChainsFetchFactory: LightChainsFetchFactoryProtocol,
        preConfiguredChainFetchFactory: PreConfiguredChainFetchFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.lightChainsFetchFactory = lightChainsFetchFactory
        self.preConfiguredChainFetchFactory = preConfiguredChainFetchFactory
        self.operationQueue = operationQueue
    }
}

// MARK: KnownNetworksListInteractorInputProtocol

extension KnownNetworksListInteractor: KnownNetworksListInteractorInputProtocol {
    func provideChains() {
        let lightChainsFetchWrapper = lightChainsFetchFactory.createWrapper()
        
        execute(
            wrapper: lightChainsFetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chains):
                self?.lightChains = chains
                self?.presenter?.didReceive(chains)
            case let .failure(error):
                self?.presenter?.didReceive(error)
            }
        }
    }
    
    func provideChain(with chainId: ChainModel.Id) {
        let chainFetchWrapper = preConfiguredChainFetchFactory.createWrapper(with: chainId)
        
        execute(
            wrapper: chainFetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chain):
                self?.presenter?.didReceive(chain)
            case let .failure(error):
                self?.presenter?.didReceive(error)
            }
        }
    }
    
    func searchChain(by query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        
        let chains = trimmedQuery.isEmpty
            ? lightChains
            : lightChains.filter { $0.name.contains(substring: trimmedQuery) }

        presenter?.didReceive(chains)
    }
}
