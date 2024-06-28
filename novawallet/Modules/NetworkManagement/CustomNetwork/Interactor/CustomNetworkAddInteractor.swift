import SubstrateSdk
import Operation_iOS

final class CustomNetworkAddInteractor: CustomNetworkBaseInteractor {
    weak var presenter: CustomNetworkAddInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
        }
    }
    
    override func handleSetupFinished(for network: ChainModel) {
        let saveOperation = repository.saveOperation(
            { [network] },
            { [] }
        )
        
        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didAddChain()
            case .failure:
                self?.presenter?.didReceive(
                    .common(innerError: .dataCorruption)
                )
            }
        }
    }
}

// MARK: CustomNetworkAddInteractorInputProtocol

extension CustomNetworkAddInteractor: CustomNetworkAddInteractorInputProtocol {
    func addNetwork(
        networkType: ChainType,
        url: String,
        name: String,
        currencySymbol: String,
        chainId: String?,
        blockExplorerURL: String?,
        coingeckoURL: String?
    ) {
        connectToChain(
            with: networkType,
            url: url,
            name: name,
            currencySymbol: currencySymbol,
            chainId: chainId,
            blockExplorerURL: blockExplorerURL,
            coingeckoURL: coingeckoURL
        )
    }
}
