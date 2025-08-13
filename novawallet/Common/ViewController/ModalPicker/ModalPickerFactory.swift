import Foundation
import UIKit_iOS
import Foundation_iOS
import NovaCrypto
import SubstrateSdk

typealias AccountDetailsPickerViewModel = LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>

enum ModalPickerFactory {
    static func createActionsList(
        title: LocalizableResource<String>?,
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

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        viewController.modalTransitioningFactory = factory

        let headerHeight = title != nil ? viewController.headerHeight : .zero

        let height = headerHeight
            + CGFloat(actions.count) * viewController.cellHeight
            + viewController.footerHeight
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

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
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
        viewController.separatorColor = R.color.colorDivider()
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

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
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

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
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

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(accounts.count) * viewController.cellHeight +
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
        viewController.separatorColor = R.color.colorDivider()
        viewController.cellHeight = 50.0
        viewController.headerHeight = 40.0
        viewController.footerHeight = 0.0
        viewController.headerBorderType = []

        viewController.viewModels = items

        let factory = ModalSheetPresentationFactory(configuration: .nova)
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
        let controller: ModalPickerViewController<
            AccountDetailsGenericSelectionCell<AccountDetailsBalanceDecorator>,
            SelectableViewModel<AccountDetailsSelectionViewModel>
        >?

        controller = createGenericCollatorsPickingList(
            items,
            actionViewModel: actionViewModel,
            selectedIndex: selectedIndex,
            delegate: delegate,
            context: context
        )

        return controller
    }

    static func createGenericCollatorsPickingList<D: AccountDetailsSelectionDecorator>(
        _ items: [AccountDetailsPickerViewModel],
        actionViewModel: LocalizableResource<IconWithTitleViewModel>?,
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> ModalPickerViewController<
        AccountDetailsGenericSelectionCell<D>,
        SelectableViewModel<AccountDetailsSelectionViewModel>
    >? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<
            AccountDetailsGenericSelectionCell<D>,
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
        viewController.isScrollEnabled = true

        if let actionViewModel = actionViewModel {
            viewController.actionType = .iconTitle(viewModel: actionViewModel)
        } else {
            viewController.actionType = .none
        }

        viewController.viewModels = items

        let factory = ModalSheetPresentationFactory(configuration: .nova)
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

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}

extension ModalPickerFactory {
    static func createSelectionList(
        title: LocalizableResource<String>?,
        items: [LocalizableResource<SelectableTitleTableViewCell.Model>],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<SelectableTitleTableViewCell, SelectableTitleTableViewCell.Model>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = title
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.separatorStyle = .none
        viewController.cellHeight = 44
        viewController.headerHeight = 42
        viewController.footerHeight = 0
        viewController.headerBorderType = []
        viewController.actionType = .none
        viewController.viewModels = items
        viewController.selectedIndex = selectedIndex

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0, height: height)
        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}

extension ModalPickerFactory {
    static func createSelectableAddressesList(
        title: LocalizableResource<String>?,
        items: [LocalizableResource<SelectableAddressTableViewCell.Model>],
        selectedIndex: Int?,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<
            SelectableAddressTableViewCell, SelectableAddressTableViewCell.Model
        > = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = title
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.separatorStyle = .none
        viewController.cellHeight = 48
        viewController.headerHeight = 42
        viewController.footerHeight = 0
        viewController.headerBorderType = []
        viewController.actionType = .none
        viewController.viewModels = items
        viewController.selectedIndex = selectedIndex ?? NSNotFound
        viewController.context = context

        let factory = ModalSheetPresentationFactory(configuration: .nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(items.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0, height: height)
        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}

extension ModalPickerFactory {
    static func createPickerListForOperations(
        operations: [DepositOperationModel],
        delegate: ModalPickerViewControllerDelegate?,
        token: String,
        context: AnyObject?
    ) -> UIViewController? {
        guard !operations.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<TokenOperationTableViewCell, TokenOperationTableViewCell.Model>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = .init {
            R.string.localizable.swapsSetupDepositTitle(
                token,
                preferredLanguages: $0.rLanguages
            )
        }

        viewController.selectedIndex = NSNotFound
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.headerBorderType = .none
        viewController.separatorStyle = .none
        viewController.separatorColor = R.color.colorDivider()
        viewController.cellHeight = 48

        viewController.viewModels = operations.map { operation in
            LocalizableResource { locale in
                TokenOperationTableViewCell.Model(
                    content: .init(
                        title: operation.titleForLocale(locale),
                        subtitle: operation.subtitleForLocale(locale, token: token),
                        icon: operation.icon
                    ),
                    isActive: operation.active
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(operations.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }
}
