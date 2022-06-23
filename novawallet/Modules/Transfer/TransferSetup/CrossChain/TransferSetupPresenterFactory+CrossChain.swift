import Foundation

extension TransferSetupPresenterFactory {
    func createCrossChainPresenter(
        for _: ChainAsset,
        destinationChainAsset _: ChainAsset,
        xcmTransfers _: XcmTransfers,
        initialState _: TransferSetupInputState,
        view _: TransferSetupChildViewProtocol
    ) -> TransferSetupChildPresenterProtocol? {
        nil
    }
}
