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

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let imageRetreiveOperationFactory = KingfisherIconRetrieveOperationFactory(operationQueue: operationQueue)

        let qrCodeFactory = QRCodeWithLogoFactory(
            iconRetrievingFactory: imageRetreiveOperationFactory,
            operationQueue: operationQueue,
            callbackQueue: .main,
            logger: Logger.shared
        )

        let interactor = AssetReceiveInteractor(
            metaChainAccountResponse: metaChainAccountResponse,
            chainAsset: chainAsset,
            qrCoderFactory: qrCoderFactory,
            qrCodeFactory: qrCodeFactory,
            appearanceFacade: AppearanceFacade.shared,
            operationQueue: operationQueue
        )
        let wireframe = AssetReceiveWireframe()
        let localizationManager = LocalizationManager.shared
        let accountShareFactory = AccountShareFactory(
            chain: chainAsset.chain,
            assetInfo: chainAsset.assetDisplayInfo,
            localizationManager: localizationManager
        )

        let networkViewModelFactory = NetworkViewModelFactory()

        let presenter = AssetReceivePresenter(
            interactor: interactor,
            wireframe: wireframe,
            iconGenerator: PolkadotIconGenerator(),
            accountShareFactory: accountShareFactory,
            networkViewModelFactory: networkViewModelFactory,
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
