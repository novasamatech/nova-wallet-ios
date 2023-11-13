import Foundation

final class TransferSetupOriginSelectionWireframe: TransferSetupWireframe {
    let assetListObservable: AssetListModelObservable

    init(assetListObservable: AssetListModelObservable) {
        self.assetListObservable = assetListObservable
    }

    override func showOriginChainSelection(
        from view: TransferSetupViewProtocol?,
        chainAsset _: ChainAsset,
        selectionState: CrossChainOriginSelectionState,
        delegate: ModalPickerViewControllerDelegate
    ) {
        guard let networkSelectionView = TransferNetworkSelectionViewFactory.createView(
            for: selectionState,
            assetListObservable: assetListObservable,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.present(networkSelectionView.controller, animated: true, completion: nil)
    }
}
