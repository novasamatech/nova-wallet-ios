import Foundation
import Foundation_iOS
import SubstrateSdk
import Kingfisher

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

        let imageManager = KingfisherManager.shared
        let remoteImageProvider = ChainLogoRemoteImageProvider(imageManager: imageManager)

        let imageRetreiveOperationFactory = ImageRetrieveOperationFactory(
            imageManager: imageManager,
            remoteProvider: remoteImageProvider
        )

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
