import Foundation
import SoraFoundation
import SoraUI

class TransferSetupWireframe: TransferSetupWireframeProtocol {
    func showDestinationChainSelection(
        from view: TransferSetupViewProtocol?,
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate
    ) {
        showChainSelection(
            from: view,
            selectionState: selectionState,
            delegate: delegate,
            context: selectionState
        )
    }

    func showOriginChainSelection(
        from view: TransferSetupViewProtocol?,
        chainAsset: ChainAsset,
        selectionState: CrossChainOriginSelectionState,
        delegate: ModalPickerViewControllerDelegate
    ) {
        let mappedState = CrossChainDestinationSelectionState(
            chain: chainAsset.chain,
            availablePeerChains: selectionState.availablePeerChainAssets.map(\.chain),
            selectedChainId: selectionState.selectedChainAssetId.chainId
        )

        showChainSelection(
            from: view,
            selectionState: mappedState,
            delegate: delegate,
            context: selectionState
        )
    }

    func showNetworkFeeAssetSelection(
        form view: ControllerBackedProtocol?,
        viewModel: SwapNetworkFeeSheetViewModel
    ) {
        let bottomSheet = SwapNetworkFeeSheetViewFactory.createView(from: viewModel)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func checkDismissing(view: TransferSetupViewProtocol?) -> Bool {
        view?.controller.navigationController?.isBeingDismissed ?? true
    }

    private func showChainSelection(
        from view: TransferSetupViewProtocol?,
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    ) {
        guard let viewController = ModalNetworksFactory.createNetworkSelectionList(
            selectionState: selectionState,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(viewController, animated: true, completion: nil)
    }
}
