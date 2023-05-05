import UIKit
import SoraFoundation
import SoraUI

enum ModalNetworksFactory {
    private static func createNetworksController<C: ModalPickerCellProtocol>(
        for title: LocalizableResource<String>
    ) -> ModalPickerViewController<C, NetworkViewModel> {
        let viewController: ModalPickerViewController<C, NetworkViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = title

        viewController.modalPresentationStyle = .custom
        viewController.separatorStyle = .none
        viewController.cellHeight = 52.0
        viewController.headerHeight = 40.0
        viewController.footerHeight = 0.0
        viewController.headerBorderType = []

        viewController.actionType = .none

        return viewController
    }

    static func createNetworkSelectionList(
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<NetworkSelectionTableViewCell, NetworkViewModel>

        let title = LocalizableResource { locale in
            R.string.localizable.xcmDestinationSelectionTitle(preferredLanguages: locale.rLanguages)
        }

        viewController = createNetworksController(for: title)
        viewController.delegate = delegate
        viewController.context = context

        let networkViewModelFactory = NetworkViewModelFactory()

        let onChainViewModel = LocalizableResource { _ in
            networkViewModelFactory.createViewModel(from: selectionState.originChain)
        }

        let onChainTitle = LocalizableResource { locale in
            R.string.localizable.commonOnChain(preferredLanguages: locale.rLanguages)
        }

        viewController.addSection(viewModels: [onChainViewModel], title: onChainTitle)

        let crossChainViewModels = selectionState.availableDestChains.map { chain in
            LocalizableResource { _ in networkViewModelFactory.createViewModel(from: chain) }
        }

        let crossChainTitle = LocalizableResource { locale in
            R.string.localizable.commonCrossChain(preferredLanguages: locale.rLanguages)
        }

        viewController.addSection(viewModels: crossChainViewModels, title: crossChainTitle)

        if selectionState.selectedChainId == selectionState.originChain.chainId {
            viewController.selectedIndex = 0
            viewController.selectedSection = 0
        } else if let index = selectionState.availableDestChains.firstIndex(
            where: { selectionState.selectedChainId == $0.chainId }
        ) {
            viewController.selectedIndex = index
            viewController.selectedSection = 1
        } else {
            viewController.selectedIndex = NSNotFound
        }

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let itemsCount = crossChainViewModels.count + 1
        let sectionsCount = 2
        let height = viewController.headerHeight + CGFloat(itemsCount) * viewController.cellHeight +
            CGFloat(sectionsCount) * viewController.sectionHeaderHeight + viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createNetworksInfoList(for networks: [ChainModel]) -> UIViewController? {
        let viewController: ModalPickerViewController<NetworkTableViewCell, NetworkViewModel>

        let title = LocalizableResource { locale in
            R.string.localizable.commonNetworksTitle(
                networks.count,
                preferredLanguages: locale.rLanguages
            )
        }

        viewController = createNetworksController(for: title)

        let networkViewModelFactory = NetworkViewModelFactory()

        let viewModels = networks.map { network in
            LocalizableResource { _ in
                networkViewModelFactory.createViewModel(from: network)
            }
        }

        viewController.viewModels = viewModels

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(networks.count) * viewController.cellHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}
