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
        case let .available(subType):
            createAvailableControlsViewModel(
                for: subType,
                giftDescription: giftDescription,
                locale: locale
            )
        case let .unavailable(subType):
            createUnavailableControlsViewModel(
                for: subType,
                giftDescription: giftDescription,
                locale: locale
            )
        }
    }

    func createAvailableControlsViewModel(
        for walletAvailabilityType: GiftedWalletType.SubType,
        giftDescription: ClaimableGiftDescription,
        locale: Locale
    ) -> GiftClaimViewModel.ControlsViewModel? {
        guard
            let claimingAccountId = giftDescription.claimingAccountId,
            let address = try? claimingAccountId.toAddress(
                using: giftDescription.chainAsset.chain.chainFormat
            ),
            let addressDrawableIcon = try? addressIconGenerator.generateFromAddress(address)
        else { return nil }

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

        let chainAccountModel: WalletView.ViewModel.ChainAccountAddressInfo = .address(
            DisplayAddressViewModel(
                address: address,
                name: nil,
                imageViewModel: DrawableIconViewModel(icon: addressDrawableIcon)
            )
        )
        let walletviewModel = WalletView.ViewModel(
            wallet: walletInfoViewModel,
            type: .account(chainAccountModel)
        )

        let walletControl = GiftClaimViewModel.WalletViewModel(
            walletViewModel: walletviewModel,
            showAccessory: showAccessory
        )

        return GiftClaimViewModel.ControlsViewModel(
            claimActionViewModel: claimAction,
            selectedWalletViewModel: walletControl
        )
    }

    func createUnavailableControlsViewModel(
        for walletAvailabilityType: GiftedWalletType.SubType,
        giftDescription: ClaimableGiftDescription,
        locale: Locale
    ) -> GiftClaimViewModel.ControlsViewModel? {
        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable

        let showAccessory = switch walletAvailabilityType {
        case .oneInSet: true
        case .single: false
        }

        let wallet = walletAvailabilityType.wallet

        let claimAction: GiftClaimViewModel.ClaimActionViewModel = .disabled(
            title: localizedStrings.giftClaimActionTitle()
        )

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
            ),
            let addressDrawableIcon = try? addressIconGenerator.generateFromAddress(address) {
            infoViewModel = .address(
                DisplayAddressViewModel(
                    address: address,
                    name: nil,
                    imageViewModel: DrawableIconViewModel(icon: addressDrawableIcon)
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

        return GiftClaimViewModel.ControlsViewModel(
            claimActionViewModel: claimAction,
            selectedWalletViewModel: walletControl
        )
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

        let actionTitle = localizedStrings.giftClaimActionTitle()

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
