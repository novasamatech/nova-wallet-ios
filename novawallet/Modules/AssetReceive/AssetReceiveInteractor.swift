import UIKit
import RobinHood

final class AssetReceiveInteractor: AnyCancellableCleaning {
    weak var presenter: AssetReceiveInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let qrCoderFactory: NovaWalletQRCoderFactoryProtocol
    let qrCodeCreationOperationFactory: QRCreationOperationFactoryProtocol
    let metaChainAccountResponse: MetaChainAccountResponse

    private let operationQueue: OperationQueue
    private var currentQRCodeOperation: CancellableCall?

    init(
        metaChainAccountResponse: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        qrCoderFactory: NovaWalletQRCoderFactoryProtocol,
        qrCodeCreationOperationFactory: QRCreationOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.metaChainAccountResponse = metaChainAccountResponse
        self.chainAsset = chainAsset
        self.qrCoderFactory = qrCoderFactory
        self.qrCodeCreationOperationFactory = qrCodeCreationOperationFactory
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

        let qrCreationOperation = qrCodeCreationOperationFactory.createOperation(
            payload: payload,
            qrSize: size
        )

        qrCreationOperation.completionBlock = { [weak self] in
            guard let self = self else {
                return
            }
            self.currentQRCodeOperation = nil

            DispatchQueue.main.async {
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
