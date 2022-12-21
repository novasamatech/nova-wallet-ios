import Foundation
import SoraFoundation

struct NewReceiveViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) -> ReceiveViewProtocol? {
        let chainAccount = metaChainAccountResponse.chainAccount
        let qrCoderFactory = WalletQRCoderFactory(
            addressPrefix: chainAccount.addressPrefix,
            chainFormat: chainAccount.chainFormat,
            publicKey: chainAccount.publicKey,
            username: chainAccount.name
        )

        let interactor = ReceiveInteractor(
            metaChainAccountResponse: metaChainAccountResponse,
            chainAsset: chainAsset,
            qrCoderFactory: qrCoderFactory,
            qrCodeCreationOperationFactory: QRCreationOperationFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = ReceiveWireframe()
        let localizationManager = LocalizationManager.shared
        let accountShareFactory = AccountShareFactory(
            chain: chainAsset.chain,
            assetInfo: chainAsset.assetDisplayInfo,
            localizationManager: localizationManager
        )

        let presenter = ReceivePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: WalletAccountViewModelFactory(),
            accountShareFactory: accountShareFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ReceiveViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
