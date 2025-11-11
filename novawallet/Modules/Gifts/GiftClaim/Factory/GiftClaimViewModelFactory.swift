import Foundation
import SubstrateSdk
import Lottie

protocol GiftClaimViewModelFactoryProtocol {
    func createViewModel(
        from giftDescription: ClaimableGiftDescription,
        giftedWallet: GiftedWalletType,
        locale: Locale
    ) -> GiftClaimViewModel?

    func createGiftUnpackingViewModel(
        for chainAsset: ChainAsset
    ) -> LottieAnimationFrameRange?
}

final class GiftClaimViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    private lazy var addressIconGenerator = PolkadotIconGenerator()
    private lazy var walletIconGenerator = NovaIconGenerator()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }
}

// MARK: - Private

private extension GiftClaimViewModelFactory {
    func createAnimation(for asset: AssetModel) -> LottieAnimation? {
        let tokenAnimationName = "\(asset.symbol)_unpacking"
        let fallbackAnimationName = Constants.defaultAnimationName

        let animation = LottieAnimation.named(tokenAnimationName, bundle: .main)
            ?? LottieAnimation.named(fallbackAnimationName, bundle: .main)

        return animation
    }

    func createControlsViewModel(
        from giftDescription: ClaimableGiftDescription,
        giftedWallet: GiftedWalletType,
        locale: Locale
    ) -> GiftClaimViewModel.ControlsViewModel? {
        switch giftedWallet {
        case .available:
            createAvailableControlsViewModel(
                for: giftedWallet,
                giftDescription: giftDescription,
                locale: locale
            )
        case .unavailable:
            createUnavailableControlsViewModel(
                for: giftedWallet,
                giftDescription: giftDescription,
                locale: locale
            )
        }
    }

    func createAvailableControlsViewModel(
        for giftedWalletType: GiftedWalletType,
        giftDescription: ClaimableGiftDescription,
        locale: Locale
    ) -> GiftClaimViewModel.ControlsViewModel? {
        let walletAvailabilityType = giftedWalletType.subtype

        guard
            let claimingAccountId = giftDescription.claimingAccountId,
            let address = try? claimingAccountId.toAddress(
                using: giftDescription.chainAsset.chain.chainFormat
            )
        else { return nil }

        let addressDrawableIcon = try? addressIconGenerator.generateFromAddress(address)

        let addressImageViewModel = addressDrawableIcon.map {
            DrawableIconViewModel(icon: $0)
        }

        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable

        let showAccessory = switch walletAvailabilityType {
        case .oneInSet: true
        case .single: false
        }

        let claimAction: GiftClaimViewModel.ClaimActionViewModel = .enabled(
            title: localizedStrings.giftClaimActionTitle()
        )

        let wallet = walletAvailabilityType.wallet

        let optIcon = wallet.walletIdenticonData().flatMap {
            try? walletIconGenerator.generateFromAccountId($0)
        }

        let iconViewModel = optIcon.map { IdentifiableDrawableIconViewModel(
            .init(icon: $0),
            identifier: wallet.metaId
        ) }

        let walletInfoViewModel = WalletView.ViewModel.WalletInfo(
            icon: iconViewModel,
            name: wallet.name
        )

        let addressViewModel = DisplayAddressViewModel(
            address: address,
            name: nil,
            imageViewModel: addressImageViewModel
        )

        let chainAccountModel: WalletView.ViewModel.ChainAccountAddressInfo = .address(addressViewModel)

        let walletviewModel = WalletView.ViewModel(
            wallet: walletInfoViewModel,
            type: .account(chainAccountModel)
        )

        let walletControl = GiftClaimViewModel.WalletViewModel(
            walletViewModel: walletviewModel,
            showAccessory: showAccessory
        )

        let warningViewModel = createWarningViewModel(
            for: giftedWalletType,
            chain: giftDescription.chainAsset.chain,
            locale: locale
        )

        return GiftClaimViewModel.ControlsViewModel(
            claimActionViewModel: claimAction,
            selectedWalletViewModel: walletControl,
            warningViewModel: nil
        )
    }

    func createUnavailableControlsViewModel(
        for giftedWalletType: GiftedWalletType,
        giftDescription: ClaimableGiftDescription,
        locale: Locale
    ) -> GiftClaimViewModel.ControlsViewModel? {
        let walletAvailabilityType = giftedWalletType.subtype

        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable

        let showAccessory: Bool
        var claimAction: GiftClaimViewModel.ClaimActionViewModel?

        switch walletAvailabilityType {
        case .oneInSet:
            showAccessory = true
            claimAction = .disabled(
                title: localizedStrings.commonSelectWallet()
            )
        case .single:
            showAccessory = false
            claimAction = nil
        }

        let wallet = walletAvailabilityType.wallet

        let optIcon = wallet.walletIdenticonData().flatMap {
            try? walletIconGenerator.generateFromAccountId($0)
        }

        let iconViewModel = optIcon.map { IdentifiableDrawableIconViewModel(
            .init(icon: $0),
            identifier: wallet.metaId
        ) }

        let walletInfoViewModel = WalletView.ViewModel.WalletInfo(
            icon: iconViewModel,
            name: wallet.name
        )

        let infoViewModel: WalletView.ViewModel.ChainAccountAddressInfo

        if
            let claimingAccountId = giftDescription.claimingAccountId,
            let address = try? claimingAccountId.toAddress(
                using: giftDescription.chainAsset.chain.chainFormat
            ) {
            let addressDrawableIcon = try? addressIconGenerator.generateFromAddress(address)
            let imageViewModel = addressDrawableIcon.map {
                DrawableIconViewModel(icon: $0)
            }
            infoViewModel = .address(
                DisplayAddressViewModel(
                    address: address,
                    name: nil,
                    imageViewModel: imageViewModel
                )
            )
        } else {
            infoViewModel = .warning(
                WalletView.ViewModel.WarningViewModel(
                    imageViewModel: StaticImageViewModel(image: R.image.iconWarning()!),
                    text: localizedStrings.accountNotFoundCaption()
                )
            )
        }

        let walletviewModel = WalletView.ViewModel(
            wallet: walletInfoViewModel,
            type: .account(infoViewModel)
        )

        let walletControl = GiftClaimViewModel.WalletViewModel(
            walletViewModel: walletviewModel,
            showAccessory: showAccessory
        )

        let warningViewModel = createWarningViewModel(
            for: giftedWalletType,
            chain: giftDescription.chainAsset.chain,
            locale: locale
        )

        return GiftClaimViewModel.ControlsViewModel(
            claimActionViewModel: claimAction,
            selectedWalletViewModel: walletControl,
            warningViewModel: warningViewModel
        )
    }

    func createWarningViewModel(
        for giftedWallet: GiftedWalletType,
        chain: ChainModel,
        locale: Locale
    ) -> WarningView.Model? {
        let wallet = giftedWallet.wallet
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable
        
        switch giftedWallet {
        case .available:
            guard wallet.fetch(for: chain.accountRequest()) == nil else {
                return nil
            }

            return WarningView.Model(
                title: localizedStrings.giftClaimWarningAccount(chain.name),
                message: nil,
                learnMore: nil
            )
        case .unavailable:
            let walletTypeString = description(for: wallet.type, locale: locale)

            let learnMoreViewModel = LearnMoreViewModel(
                iconViewModel: nil,
                title: localizedStrings.giftClaimWarningWalletManageAction()
            )

            return WarningView.Model(
                title: localizedStrings.giftClaimWarningWalletTitle(walletTypeString),
                message: localizedStrings.giftClaimWarningWalletMessage(),
                learnMore: learnMoreViewModel
            )
        }
    }

    func description(
        for walletType: MetaAccountModelType,
        locale: Locale
    ) -> String {
        let languages = locale.rLanguages

        return switch walletType {
        case .secrets:
            R.string(preferredLanguages: languages).localizable.commonAccount()
        case .watchOnly:
            R.string(preferredLanguages: languages).localizable.commonWatchOnly()
        case .paritySigner:
            R.string(preferredLanguages: languages).localizable.commonParitySigner()
        case .ledger, .genericLedger:
            R.string(preferredLanguages: languages).localizable.commonLedger()
        case .polkadotVault:
            R.string(preferredLanguages: languages).localizable.commonPolkadotVault()
        case .proxied:
            R.string(preferredLanguages: languages).localizable.commonProxied()
        case .multisig:
            R.string(preferredLanguages: languages).localizable.commonMultisig()
        }
    }
}

// MARK: - GiftClaimViewModelFactoryProtocol

extension GiftClaimViewModelFactory: GiftClaimViewModelFactoryProtocol {
    func createViewModel(
        from giftDescription: ClaimableGiftDescription,
        giftedWallet: GiftedWalletType,
        locale: Locale
    ) -> GiftClaimViewModel? {
        guard
            let animation = createAnimation(for: giftDescription.chainAsset.asset),
            let controlsViewModel = createControlsViewModel(
                from: giftDescription,
                giftedWallet: giftedWallet,
                locale: locale
            )
        else { return nil }

        let animationRange = LottieAnimationFrameRange(
            startFrame: Constants.animationInitialFrame,
            endFrame: Constants.animationGiftUnpackingFrame
        )

        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable

        let assetDisplayInfo = giftDescription.chainAsset.assetDisplayInfo

        let title = localizedStrings.giftClaimTitle()

        let amount = balanceViewModelFactory.amountFromValue(
            giftDescription.amount.value.decimal(assetInfo: assetDisplayInfo)
        ).value(for: locale)

        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(from: assetDisplayInfo)

        return GiftClaimViewModel(
            title: title,
            animation: animation,
            animationFrameRange: animationRange,
            amount: amount,
            assetIcon: assetIcon,
            controlsViewModel: controlsViewModel
        )
    }

    func createGiftUnpackingViewModel(
        for chainAsset: ChainAsset
    ) -> LottieAnimationFrameRange? {
        guard let animation = createAnimation(for: chainAsset.asset) else {
            return nil
        }

        return LottieAnimationFrameRange(
            startFrame: Constants.animationGiftUnpackingFrame,
            endFrame: animation.endFrame
        )
    }
}

// MARK: - Constants

private extension GiftClaimViewModelFactory {
    enum Constants {
        static let animationInitialFrame: CGFloat = 0
        static let animationGiftUnpackingFrame: CGFloat = 180
        static let defaultAnimationName: String = "Default_unpacking"
    }
}
