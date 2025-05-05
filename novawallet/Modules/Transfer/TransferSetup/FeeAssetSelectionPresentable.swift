import Foundation
import UIKit_iOS
import Foundation_iOS

protocol FeeAssetSelectionPresentable {
    func showFeeAssetSelection(
        from view: ControllerBackedProtocol?,
        utilityAsset: ChainAsset,
        sendingAsset: ChainAsset,
        currentFeeAsset: ChainAsset?,
        onFeeAssetSelect: ((ChainAsset) -> Void)?
    )
}

extension FeeAssetSelectionPresentable {
    func showFeeAssetSelection(
        from view: ControllerBackedProtocol?,
        utilityAsset: ChainAsset,
        sendingAsset: ChainAsset,
        currentFeeAsset: ChainAsset?,
        onFeeAssetSelect: ((ChainAsset) -> Void)?
    ) {
        let viewModel = createViewModel(
            utilityAsset: utilityAsset,
            sendingAsset: sendingAsset,
            currentFeeAsset: currentFeeAsset,
            onFeeAssetSelect: onFeeAssetSelect
        )

        let bottomSheet = FeeAssetSelectSheetViewFactory.createView(from: viewModel)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    private func createViewModel(
        utilityAsset: ChainAsset,
        sendingAsset: ChainAsset,
        currentFeeAsset: ChainAsset?,
        onFeeAssetSelect: ((ChainAsset) -> Void)?
    ) -> FeeAssetSelectSheetViewModel {
        let payAssetSelected = currentFeeAsset?.chainAssetId == sendingAsset.chainAssetId

        let selectedIndex = payAssetSelected
            ? FeeSelectionViewModel.payAsset.rawValue
            : FeeSelectionViewModel.utilityAsset.rawValue

        let sectionTitle: (Int) -> LocalizableResource<String> = { section in
            .init { _ in
                FeeSelectionViewModel(rawValue: section) == .utilityAsset
                    ? utilityAsset.asset.symbol
                    : sendingAsset.asset.symbol
            }
        }

        let action: (Int) -> Void = {
            let chainAsset = FeeSelectionViewModel(rawValue: $0) == .utilityAsset
                ? utilityAsset
                : sendingAsset

            onFeeAssetSelect?(chainAsset)
        }

        return FeeAssetSelectSheetViewModel(
            title: FeeSelectionViewModel.title,
            message: FeeSelectionViewModel.message,
            sectionTitle: sectionTitle,
            action: action,
            selectedIndex: selectedIndex,
            count: FeeSelectionViewModel.allCases.count,
            hint: FeeSelectionViewModel.hint
        )
    }
}
