import Foundation
import SoraFoundation
import SubstrateSdk

struct AssetReceiveViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    ) -> AssetReceiveViewProtocol? {
        let chainAccount = metaChainAccountResponse.chainAccount
        let qrCoderFactory = WalletQRCoderFactory(
            chainFormat: chainAccount.chainFormat,
            publicKey: chainAccount.publicKey
        )

        let interactor = AssetReceiveInteractor(
            metaChainAccountResponse: metaChainAccountResponse,
            chainAsset: chainAsset,
            qrCoderFactory: qrCoderFactory,
            qrCodeCreationOperationFactory: QRCreationOperationFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = AssetReceiveWireframe()
        let localizationManager = LocalizationManager.shared
        let accountShareFactory = AccountShareFactory(
            chain: chainAsset.chain,
            assetInfo: chainAsset.assetDisplayInfo,
            localizationManager: localizationManager
        )

        let presenter = AssetReceivePresenter(
            interactor: interactor,
            wireframe: wireframe,
            iconGenerator: PolkadotIconGenerator(),
            accountShareFactory: accountShareFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = AssetReceiveViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
