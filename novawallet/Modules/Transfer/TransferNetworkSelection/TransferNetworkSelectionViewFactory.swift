import Foundation
import UIKit_iOS
import Foundation_iOS

struct TransferNetworkSelectionViewFactory {
    static func createView(
        for selectionState: CrossChainOriginSelectionState,
        assetListObservable: AssetListModelObservable,
        delegate: ModalPickerViewControllerDelegate
    ) -> TransferNetworkSelectionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = TransferNetworkSelectionInteractor(assetListObservable: assetListObservable)

        let balanceViewModelFactory = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = TransferNetworkSelectionPresenter(
            chainAssets: selectionState.availablePeerChainAssets,
            interactor: interactor,
            balanceViewModeFactoryFacade: balanceViewModelFactory,
            networkViewModelFactory: NetworkViewModelFactory()
        )

        let viewController = TransferNetworkSelectionViewController(viewModelPresenter: presenter)

        presenter.view = viewController
        interactor.presenter = presenter

        viewController.localizedTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonFromNetwork()
        }

        viewController.modalPresentationStyle = .custom
        viewController.separatorStyle = .none
        viewController.headerBorderType = []
        viewController.actionType = .none
        viewController.delegate = delegate
        viewController.context = selectionState
        viewController.isScrollEnabled = true
        viewController.cellHeight = 52

        let sectionTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonCrossChain()
        }

        viewController.addSection(viewModels: [], title: sectionTitle)

        if let index = selectionState.availablePeerChainAssets.firstIndex(
            where: { selectionState.selectedChainAssetId == $0.chainAssetId }
        ) {
            viewController.selectedIndex = index
        } else {
            viewController.selectedIndex = NSNotFound
        }

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let itemsCount = selectionState.availablePeerChainAssets.count
        let sectionsCount = 1
        let height = viewController.headerHeight + CGFloat(itemsCount) * viewController.cellHeight +
            CGFloat(sectionsCount) * viewController.sectionHeaderHeight

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: min(height, maxHeight))

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}
