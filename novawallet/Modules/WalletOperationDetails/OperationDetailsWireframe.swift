import Foundation
import CommonWallet

final class OperationDetailsWireframe: OperationDetailsWireframeProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    func showSend(
        from _: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    ) {
        guard let peerId = try? displayAddress.address.toAccountId().toHex() else {
            return
        }

        let assetId = ChainAssetId(
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        ).walletId

        let receiverInfo = ReceiveInfo(
            accountId: peerId,
            assetId: assetId,
            amount: nil,
            details: nil
        )

        let transferPayload = TransferPayload(
            receiveInfo: receiverInfo,
            receiverName: displayAddress.username
        )

        if let command = commandFactory?.prepareTransfer(with: transferPayload) {
            command.presentationStyle = .push(hidesBottomBar: true)
            try? command.execute()
        }
    }
}
