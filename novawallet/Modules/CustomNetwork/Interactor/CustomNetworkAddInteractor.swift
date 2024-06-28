import SubstrateSdk
import Operation_iOS

final class CustomNetworkAddInteractor: CustomNetworkBaseInteractor {
    weak var presenter: CustomNetworkAddInteractorOutputProtocol? {
        didSet {
            basePresenter = presenter
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
    ) {}
}
