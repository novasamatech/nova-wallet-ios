import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

struct SignerConnectViewFactory {
    static func createBeaconView(for info: BeaconConnectionInfo) -> SignerConnectViewProtocol? {
        let selectedChain = Chain.westend
        let selectedWallet = SelectedWalletSettings.shared.value

        let request = ChainAccountRequest(
            chainId: selectedChain.genesisHash,
            addressPrefix: UInt16(selectedChain.addressType.rawValue),
            isEthereumBased: false
        )

        guard let selectedAccount = try? selectedWallet?.fetch(for: request)?.toAccountItem() else {
            return nil
        }

        let interactor = SignerConnectInteractor(
            selectedAccount: selectedAccount,
            chain: selectedChain,
            info: info,
            logger: Logger.shared
        )

        let wireframe = SignerConnectWireframe()

        let viewModelFactory = SignerConnectViewModelFactory()
        let presenter = SignerConnectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: selectedChain
        )

        let view = SignerConnectViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
