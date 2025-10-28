import Foundation

final class GiftTransferSetupWireframe: GiftTransferSetupWireframeProtocol {
    func showConfirmation(
        from _: (any TransferSetupChildViewProtocol)?,
        chainAsset _: ChainAsset,
        sendingAmount _: OnChainTransferAmount<Decimal>,
        recepient _: AccountAddress
    ) {}
}
