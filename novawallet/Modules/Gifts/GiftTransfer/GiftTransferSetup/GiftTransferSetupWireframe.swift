import Foundation

final class GiftTransferSetupWireframe: GiftTransferSetupWireframeProtocol {
    func showConfirmation(
        from _: (any GiftTransferSetupViewProtocol)?,
        chainAsset _: ChainAsset,
        sendingAmount _: OnChainTransferAmount<Decimal>
    ) {}
}
