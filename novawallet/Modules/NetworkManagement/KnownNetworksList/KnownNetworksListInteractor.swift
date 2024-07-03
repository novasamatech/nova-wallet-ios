import UIKit
import Operation_iOS

final class KnownNetworksListInteractor {
    weak var presenter: KnownNetworksListInteractorOutputProtocol?
    
    private let dataFetchFactory: DataOperationFactoryProtocol
    private let chainConverter: ChainModelConversionProtocol
    private let operationQueue: OperationQueue
    
    init(
        dataFetchFactory: any DataOperationFactoryProtocol,
        chainConverter: any ChainModelConversionProtocol,
        operationQueue: OperationQueue
    ) {
        self.dataFetchFactory = dataFetchFactory
        self.chainConverter = chainConverter
        self.operationQueue = operationQueue
    }
}

// MARK: KnownNetworksListInteractorInputProtocol

extension KnownNetworksListInteractor: KnownNetworksListInteractorInputProtocol {
    func provideChains() {
        let fetchChainsWrapper = createFetchChainsWrapper(using: chainConverter)
        
        execute(
            wrapper: fetchChainsWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chains):
                self?.presenter?.didReceive(chains)
            case let .failure(error):
                self?.presenter?.didReceive(error)
            }
        }
    }
}

// MARK: Private

private extension KnownNetworksListInteractor {
    func createFetchChainsWrapper(using converter: ChainModelConversionProtocol) -> CompoundOperationWrapper<[ChainModel]> {
        let fetchOperation = dataFetchFactory.fetchData(from: ApplicationConfig.shared.preConfiguredChainListURL)
        
        let mapOperation = ClosureOperation<[ChainModel]> {
            let remoteData = try fetchOperation.extractNoCancellableResultData()
            
            let remoteItems = try JSONDecoder().decode(
                [RemoteChainModel].self,
                from: remoteData
            )
            
            return remoteItems
                .enumerated()
                .compactMap {
                    converter.update(
                        localModel: nil,
                        remoteModel: $0.element,
                        additionalAssets: [],
                        order: Int64($0.offset)
                    )
                }
        }
        
        mapOperation.addDependency(fetchOperation)
        
        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchOperation]
        )
    }
}
