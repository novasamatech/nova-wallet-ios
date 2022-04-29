import Foundation
import SoraUI
import SoraFoundation
import IrohaCrypto
import SubstrateSdk

enum AccountHeaderType {
    case title(_ title: LocalizableResource<String>)
    case address(_ type: SNAddressType, title: LocalizableResource<String>)
}

enum ModalPickerFactory {
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
        createPickerList(
            accounts,
            selectedAccount: selectedAccount,
            headerType: .title(title),
            delegate: delegate,
            context: context
        )
    }

    static func createPickerList(
        _ accounts: [MetaChainAccountResponse],
        selectedAccount: MetaChainAccountResponse?,
        headerType: AccountHeaderType,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        let viewController: ModalPickerViewController<AccountPickerTableViewCell, WalletAccountViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        switch headerType {
        case let .title(title):
            viewController.localizedTitle = title
        case let .address(type, title):
            viewController.localizedTitle = title
            viewController.icon = type.icon
            viewController.actionType = .add
        }

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.headerBorderType = []
        viewController.cellHeight = 56.0
        viewController.footerHeight = 16.0

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
        _ items: [StakingManageOption],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) -> UIViewController? {
        guard !items.isEmpty else {
            return nil
        }

        let viewController: ModalPickerViewController<StakingManageCell, StakingManageViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.stakingManageTitle(preferredLanguages: locale.rLanguages)
        }

        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context
        viewController.selectedIndex = NSNotFound
        viewController.separatorStyle = .singleLine
        viewController.cellHeight = StakingManageCell.cellHeight

        viewController.viewModels = items.map { type in
            LocalizableResource { locale in
                StakingManageViewModel(
                    icon: type.icon,
                    title: type.titleForLocale(locale),
                    details: type.detailsForLocale(locale)
                )
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: .fearless)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight
            + CGFloat(items.count) * viewController.cellHeight
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
}
