import UIKit
import Operation_iOS

enum AssetIconURLFactory {
    static func createURL(
        for iconName: String?,
        iconAppearance: AppearanceIconsOptions
    ) -> URL? {
        guard let iconName else { return nil }

        return switch iconAppearance {
        case .white:
            URL(string: ApplicationConfig.shared.whiteAppearanceIconsPath + iconName)
        case .colored:
            URL(string: ApplicationConfig.shared.coloredAppearanceIconsPath + iconName)
        }
    }
}

final class AssetReceiveInteractor: AnyCancellableCleaning {
    weak var presenter: AssetReceiveInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let qrCoderFactory: NovaWalletQRCoderFactoryProtocol
    let qrCodeCreationOperationFactory: QRCreationOperationFactoryProtocol
    let metaChainAccountResponse: MetaChainAccountResponse
    let appearanceFacade: AppearanceFacadeProtocol

    private let operationQueue: OperationQueue
    private var currentQRCodeOperation: CancellableCall?

    init(
        metaChainAccountResponse: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        qrCoderFactory: NovaWalletQRCoderFactoryProtocol,
        qrCodeCreationOperationFactory: QRCreationOperationFactoryProtocol,
        appearanceFacade: AppearanceFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.metaChainAccountResponse = metaChainAccountResponse
        self.chainAsset = chainAsset
        self.qrCoderFactory = qrCoderFactory
        self.qrCodeCreationOperationFactory = qrCodeCreationOperationFactory
        self.appearanceFacade = appearanceFacade
        self.operationQueue = operationQueue
    }

    private func updateQRCode(size: CGSize) {
        clear(cancellable: &currentQRCodeOperation)

        let encoder = qrCoderFactory.createEncoder()
        let receiverInfo = AssetReceiveInfo(
            accountId: metaChainAccountResponse.chainAccount.accountId.toHex(),
            assetId: chainAsset.chainAssetId.walletId,
            amount: nil,
            details: nil
        )
        guard let payload = try? encoder.encode(receiverInfo: receiverInfo) else {
            presenter.didReceive(error: .encodingData)
            return
        }

        let iconURL = AssetIconURLFactory.createURL(
            for: chainAsset.asset.icon,
            iconAppearance: appearanceFacade.selectedIconAppearance
        )

        let qrCreationOperation = qrCodeCreationOperationFactory.createOperation(
            payload: payload,
            logoURL: iconURL,
            qrSize: size
        )

        qrCreationOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.currentQRCodeOperation === qrCreationOperation else {
                    return
                }

                self.currentQRCodeOperation = nil

                do {
                    let qrImage = try qrCreationOperation.extractNoCancellableResultData()
                    self.presenter.didReceive(qrCodeInfo: .init(
                        image: qrImage,
                        encodingData: receiverInfo
                    ))
                } catch {
                    self.presenter.didReceive(error: .generatingQRCode)
                }
            }
        }

        currentQRCodeOperation = qrCreationOperation
        operationQueue.addOperation(qrCreationOperation)
    }
}

extension AssetReceiveInteractor: AssetReceiveInteractorInputProtocol {
    func setup() {
        presenter.didReceive(
            account: metaChainAccountResponse,
            chain: chainAsset.chain,
            token: chainAsset.assetDisplayInfo.symbol
        )
    }

    func generateQRCode(size: CGSize) {
        updateQRCode(size: size)
    }
}
