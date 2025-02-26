import UIKit
import Operation_iOS

final class AssetReceiveInteractor: AnyCancellableCleaning {
    weak var presenter: AssetReceiveInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let qrCodeFactory: QRCodeWithLogoFactoryProtocol
    let qrCoderFactory: NovaWalletQRCoderFactoryProtocol
    let metaChainAccountResponse: MetaChainAccountResponse
    let appearanceFacade: AppearanceFacadeProtocol

    private let operationQueue: OperationQueue
    private var currentQRCodeOperation: CancellableCall?

    init(
        metaChainAccountResponse: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        qrCoderFactory: NovaWalletQRCoderFactoryProtocol,
        qrCodeFactory: QRCodeWithLogoFactoryProtocol,
        appearanceFacade: AppearanceFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.metaChainAccountResponse = metaChainAccountResponse
        self.chainAsset = chainAsset
        self.qrCoderFactory = qrCoderFactory
        self.qrCodeFactory = qrCodeFactory
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

        let qrLogoType = AssetIconURLFactory.createQRLogoURL(
            for: chainAsset.asset.icon,
            iconAppearance: appearanceFacade.selectedIconAppearance
        )

        let logoInfo = ChainLogoImageInfo(
            size: .qrLogoSize,
            scale: UIScreen.main.scale,
            type: qrLogoType
        )

        let resultClosure: (Result<QRCodeWithLogoFactory.QRCreationResult, Error>) -> Void = { [weak self] result in
            switch result {
            case let .success(qrCode):
                self?.presenter.didReceive(qrCodeInfo: .init(
                    result: qrCode,
                    encodingData: receiverInfo
                ))
            case .failure:
                self?.presenter.didReceive(error: .generatingQRCode)
            }
        }

        qrCodeFactory.createQRCode(
            with: payload,
            logoInfo: logoInfo,
            qrSize: size,
            partialResultClosure: resultClosure,
            completion: resultClosure
        )
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
