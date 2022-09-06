import Foundation
import SoraUI
import SoraFoundation
import IrohaCrypto
import SubstrateSdk

typealias AccountDetailsPickerViewModel = LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>

enum ModalPickerFactory {
    static func createActionsList(
        title: LocalizableResource<String>,
        actions: [LocalizableResource<ActionManageViewModel>],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<ActionManageTableViewCell, ActionManageViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = title

        viewController.selectedIndex = NSNotFound
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.headerBorderType = .none
        viewController.separatorStyle = .none
        viewController.cellHeight = 48.0

        viewController.viewModels = actions

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(actions.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createStakingManageSource(
        options: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !options.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<ActionManageTableViewCell, ActionManageViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.parastkManageCollators(preferredLanguages: locale.rLanguages)
        }

        viewController.selectedIndex = NSNotFound
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.headerBorderType = .none
        viewController.separatorStyle = .none
        viewController.cellHeight = 48.0

        viewController.viewModels = options.map { option in
            LocalizableResource { locale in
                ActionManageViewModel(
                    icon: option.icon,
                    title: option.titleForLocale(locale, statics: nil),
                    details: nil
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(options.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerListForSecretSource(
        options: [SecretSource],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !options.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<SecretTypeTableViewCell, IconWithTitleSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.secretTypePickerTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.selectedIndex = NSNotFound
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.headerBorderType = .none
        viewController.separatorStyle = .singleLine
        viewController.separatorColor = R.color.colorDarkGray()
        viewController.cellHeight = 48.0

        viewController.viewModels = options.map { option in
            LocalizableResource { locale in
                IconWithTitleSubtitleViewModel(
                    title: option.titleForLocale(locale),
                    subtitle: option.subtitleForLocale(locale),
                    icon: option.icon
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(options.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        _ types: [MultiassetCryptoType],
        selectedType: MultiassetCryptoType?,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !types.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.commonCryptoType(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.titleWithSubtitleTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        if let selectedType = selectedType {
            viewController.selectedIndex = types.firstIndex(of: selectedType) ?? 0
        } else {
            viewController.selectedIndex = 0
        }

        viewController.viewModels = types.map { type in
            LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: type.titleForLocale(locale),
                    subtitle: type.subtitleForLocale(locale)
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(types.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerList(
        _ accounts: [MetaChainAccountResponse],
        selectedAccount: MetaChainAccountResponse?,
        title: LocalizableResource<String>,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<AccountPickerTableViewCell, WalletAccountViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = title

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.headerBorderType = []
        viewController.cellHeight = 56.0
        viewController.footerHeight = 16.0
        viewController.isScrollEnabled = true

        if let selectedAccount = selectedAccount {
            viewController.selectedIndex = accounts.firstIndex { account in
                account.chainAccount.chainId == selectedAccount.chainAccount.chainId &&
                    account.chainAccount.accountId == selectedAccount.chainAccount.accountId
            } ?? NSNotFound
        } else {
            viewController.selectedIndex = NSNotFound
        }

        let viewModelFactory = WalletAccountViewModelFactory()

        viewController.viewModels = accounts.compactMap { account in
            let optViewModel = try? viewModelFactory.createViewModel(from: account)
            return optViewModel.map { viewModel in LocalizableResource { _ in viewModel } }
        }

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(accounts.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        _ items: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<PurchaseProviderPickerTableViewCell, IconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.walletAssetBuyWith(preferredLanguages: locale.rLanguages)
        }

        viewController.cellNib = UINib(resource: R.nib.purchaseProviderPickerTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.selectedIndex = NSNotFound

        viewController.viewModels = items.map { type in
            LocalizableResource { _ in
                IconWithTitleViewModel(
                    icon: type.icon,
                    title: type.title
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerForList(
        _ items: [LocalizableResource<StakingAmountViewModel>],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<BottomSheetInfoBalanceCell, StakingAmountViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)
        }

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.selectedIndex = NSNotFound
        viewController.separatorStyle = .singleLine
        viewController.separatorColor = R.color.colorWhite8()
        viewController.cellHeight = 50.0
        viewController.headerHeight = 40.0
        viewController.footerHeight = 0.0
        viewController.headerBorderType = []

        viewController.viewModels = items

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createCollatorsPickingList(
        _ items: [AccountDetailsPickerViewModel],
        actionViewModel: LocalizableResource<IconWithTitleViewModel>?,
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<
            AccountDetailsSelectionCell,
            SelectableViewModel<AccountDetailsSelectionViewModel>
        >
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.parachainStakingCollator(preferredLanguages: locale.rLanguages)
        }

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.selectedIndex = selectedIndex
        viewController.separatorStyle = .none
        viewController.cellHeight = 56.0
        viewController.headerHeight = 40.0
        viewController.footerHeight = 0.0
        viewController.headerBorderType = []

        if let actionViewModel = actionViewModel {
            viewController.actionType = .iconTitle(viewModel: actionViewModel)
        } else {
            viewController.actionType = .none
        }

        viewController.viewModels = items

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let itemsCount = actionViewModel != nil ? items.count + 1 : items.count
        let height = viewController.headerHeight + CGFloat(itemsCount) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createCollatorsSelectionList(
        _ items: [LocalizableResource<AccountDetailsSelectionViewModel>],
        delegate: ModalPickerViewControllerDelegate?,
        title: LocalizableResource<String>,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<
            AccountDetailsNavigationCell,
            AccountDetailsSelectionViewModel
        >
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = title

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.separatorStyle = .none
        viewController.cellHeight = 56.0
        viewController.headerHeight = 40.0
        viewController.footerHeight = 0.0
        viewController.headerBorderType = []
        viewController.selectedIndex = NSNotFound

        viewController.actionType = .none

        viewController.viewModels = items

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createNetworkSelectionList(
        selectionState: CrossChainDestinationSelectionState,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<NetworkSelectionTableViewCell, NetworkViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.xcmDestinationSelectionTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.separatorStyle = .none
        viewController.cellHeight = 52.0
        viewController.headerHeight = 40.0
        viewController.footerHeight = 0.0
        viewController.headerBorderType = []

        viewController.actionType = .none

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

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let itemsCount = crossChainViewModels.count + 1
        let sectionsCount = 2
        let height = viewController.headerHeight + CGFloat(itemsCount) * viewController.cellHeight +
            CGFloat(sectionsCount) * viewController.sectionHeaderHeight + viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}
