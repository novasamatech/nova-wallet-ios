import UIKit

protocol DAppWalletAuthViewModelFactoryProtocol {
    func createViewModel(
        from request: DAppAuthRequest,
        wallet: MetaAccountModel,
        totalWalletValue: Decimal?,
        locale: Locale
    ) -> DAppWalletAuthViewModel?
}

final class DAppWalletAuthViewModelFactory {
    let walletViewModelFactory = WalletAccountViewModelFactory()
    let networksViewModelFactory = DAppNetworksViewModelFactory()

    let fiatBalanceInfoFactory: BalanceViewModelFactoryProtocol

    init(fiatBalanceInfoFactory: BalanceViewModelFactoryProtocol) {
        self.fiatBalanceInfoFactory = fiatBalanceInfoFactory
    }

    private func createImageViewModel(from staticImage: UIImage) -> ImageViewModelProtocol {
        StaticImageViewModel(image: staticImage)
    }

    private func createDAppImageViewModel(from url: URL?) -> ImageViewModelProtocol {
        if let url = url {
            return RemoteImageViewModel(url: url)
        } else {
            return createImageViewModel(from: R.image.iconDefaultDapp()!)
        }
    }

    private func createWalletViewModel(
        from wallet: MetaAccountModel,
        totalValue: Decimal?,
        locale: Locale
    ) throws -> WalletTotalAmountView.ViewModel {
        let viewModel = try walletViewModelFactory.createDisplayViewModel(from: wallet)

        let totalValueString = totalValue.flatMap { fiatBalanceInfoFactory.amountFromValue($0) }

        return .init(
            icon: viewModel.imageViewModel,
            name: viewModel.name,
            amount: totalValueString?.value(for: locale) ?? ""
        )
    }

    private func detectNetworksWarning(
        from request: DAppAuthRequest,
        locale: Locale
    ) -> String? {
        guard request.requiredChains.hasUnresolved else {
            return nil
        }

        return R.string(preferredLanguages: locale.rLanguages).localizable.dappsMissingRequiredNetworksWarningFormat(request.dApp)
    }

    private func detectWalletWarning(
        from request: DAppAuthRequest,
        wallet: MetaAccountModel,
        locale: Locale
    ) -> String? {
        let noAccountChains = request.requiredChains.resolved.filter { chain in
            wallet.fetch(for: chain.accountRequest()) == nil
        }

        guard !noAccountChains.isEmpty else {
            return nil
        }

        let chains = noAccountChains.sorted { chain1, chain2 in
            ChainModelCompator.defaultComparator(chain1: chain1, chain2: chain2)
        }

        let name = networksViewModelFactory.createChainNamesString(
            from: chains,
            maxCount: 3,
            locale: locale
        )

        return R.string(preferredLanguages: locale.rLanguages
        ).localizable.missingAccountsWarningFormat(format: chains.count, format: name)
    }
}

extension DAppWalletAuthViewModelFactory: DAppWalletAuthViewModelFactoryProtocol {
    func createViewModel(
        from request: DAppAuthRequest,
        wallet: MetaAccountModel,
        totalWalletValue: Decimal?,
        locale: Locale
    ) -> DAppWalletAuthViewModel? {
        guard let walletViewModel = try? createWalletViewModel(
            from: wallet,
            totalValue: totalWalletValue,
            locale: locale
        ) else {
            return nil
        }

        let sourceViewModel = createImageViewModel(from: R.image.iconDappExtension()!)
        let destinationViewModel = createDAppImageViewModel(from: request.dAppIcon)

        let resolution = request.optionalChains?.merging(with: request.requiredChains) ??
            request.requiredChains
        let networksViewModel = networksViewModelFactory.createViewModel(from: resolution)
        let networksWarning = detectNetworksWarning(from: request, locale: locale)

        let walletWarning = detectWalletWarning(
            from: request,
            wallet: wallet,
            locale: locale
        )

        return .init(
            sourceImageViewModel: sourceViewModel,
            destinationImageViewModel: destinationViewModel,
            dAppName: request.dApp,
            dAppHost: request.origin ?? "",
            networks: networksViewModel,
            networksWarning: networksWarning,
            wallet: walletViewModel,
            walletWarning: walletWarning
        )
    }
}
