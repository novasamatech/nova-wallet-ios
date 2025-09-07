import UIKit
import Foundation_iOS
import UIKit_iOS

enum ModalNetworksFactory {
    private static func createNetworksController<C: ModalPickerCellProtocol>(
        for title: LocalizableResource<String>
    ) -> ModalPickerViewController<C, NetworkViewModel> {
        let viewController: ModalPickerViewController<C, NetworkViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = title

        viewController.modalPresentationStyle = .custom
        viewController.separatorStyle = .none
        viewController.headerBorderType = []

        viewController.actionType = .none

        return viewController
    }

    private static func createDAppsNetworksController(
        for title: LocalizableResource<String>
    ) -> ModalPickerViewController<NetworkTableViewCell, NetworkViewModel> {
        let viewController: ModalPickerViewController<NetworkTableViewCell, NetworkViewModel>
            = createNetworksController(for: title)

        viewController.cellHeight = 48.0
        viewController.headerHeight = 32.0
        viewController.footerHeight = 0.0
        viewController.sectionHeaderHeight = 32
        viewController.sectionFooterHeight = 32
        viewController.isScrollEnabled = true

        return viewController
    }

    static func createNetworkSelectionList(
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<NetworkSelectionTableViewCell, NetworkViewModel>

        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.xcmDestinationSelectionTitle()
        }

        viewController = createNetworksController(for: title)
        viewController.delegate = delegate
        viewController.context = context
        viewController.isScrollEnabled = true

        let networkViewModelFactory = NetworkViewModelFactory()

        let onChainViewModel = LocalizableResource { _ in
            networkViewModelFactory.createViewModel(from: selectionState.chain)
        }

        let onChainTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonOnChain()
        }

        viewController.addSection(viewModels: [onChainViewModel], title: onChainTitle)

        let crossChainViewModels = selectionState.availablePeerChains.map { chain in
            LocalizableResource { _ in networkViewModelFactory.createViewModel(from: chain) }
        }

        let crossChainTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonCrossChain()
        }

        viewController.addSection(viewModels: crossChainViewModels, title: crossChainTitle)

        if selectionState.selectedChainId == selectionState.chain.chainId {
            viewController.selectedIndex = 0
            viewController.selectedSection = 0
        } else if let index = selectionState.availablePeerChains.firstIndex(
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

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: min(height, maxHeight))

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createNetworksInfoList(for networks: [ChainModel]) -> UIViewController? {
        let viewController: ModalPickerViewController<NetworkTableViewCell, NetworkViewModel>

        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworksTitle(
                networks.count
            )
        }

        viewController = createDAppsNetworksController(for: title)

        viewController.viewModels = convertNetworkListToViewModels(from: networks)

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(networks.count) * viewController.cellHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createResolutionInfoList(
        for requiredResolution: DAppChainsResolution,
        optionalResolution: DAppChainsResolution?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<NetworkTableViewCell, NetworkViewModel>

        let networksCount = requiredResolution.totalChainsCount + (optionalResolution?.totalChainsCount ?? 0)

        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.commonNetworksTitle(
                networksCount
            )
        }

        viewController = createDAppsNetworksController(for: title)

        let rowsCount = requiredResolution.resolved.count + (optionalResolution?.resolved.count ?? 0)
        var sectionsCount: Int = 0
        var footersCount: Int = 0

        if requiredResolution.hasChains {
            let hasFooter = addNetworksSection(
                to: viewController,
                from: requiredResolution,
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.dappsRequiredNetworks()
                }
            )

            sectionsCount += 1

            if hasFooter {
                footersCount += 1
            }
        }

        if let optionalResolution = optionalResolution, optionalResolution.hasChains {
            let hasFooter = addNetworksSection(
                to: viewController,
                from: optionalResolution,
                title: LocalizableResource { locale in
                    R.string(preferredLanguages: locale.rLanguages).localizable.dappsOptionalNetworks()
                }
            )

            sectionsCount += 1

            if hasFooter {
                footersCount += 1
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight +
            CGFloat(rowsCount) * viewController.cellHeight +
            CGFloat(sectionsCount) * viewController.sectionHeaderHeight +
            CGFloat(footersCount) * viewController.sectionFooterHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    private static func addNetworksSection(
        to viewController: ModalPickerViewController<NetworkTableViewCell, NetworkViewModel>,
        from resolution: DAppChainsResolution,
        title: LocalizableResource<String>
    ) -> Bool {
        let requiredViewModels = convertNetworkSetToViewModels(from: resolution.resolved)

        let sectionFooter: LocalizableResource<String>?

        if resolution.hasUnresolved {
            sectionFooter = LocalizableResource { locale in
                R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.dappsUnsupportedNetworksFormat(
                    format: resolution.unresolved.count
                )
            }
        } else {
            sectionFooter = nil
        }

        viewController.addSection(
            viewModels: requiredViewModels,
            title: title,
            footer: sectionFooter
        )

        return sectionFooter != nil
    }

    private static func convertNetworkListToViewModels(
        from networkList: [ChainModel]
    ) -> [LocalizableResource<NetworkViewModel>] {
        let networkViewModelFactory = NetworkViewModelFactory()

        return networkList.map { network in
            LocalizableResource { _ in
                networkViewModelFactory.createViewModel(from: network)
            }
        }
    }

    private static func convertNetworkSetToViewModels(
        from networkSet: Set<ChainModel>
    ) -> [LocalizableResource<NetworkViewModel>] {
        let networkList = networkSet.sorted(by: { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        })

        return convertNetworkListToViewModels(from: networkList)
    }
}
