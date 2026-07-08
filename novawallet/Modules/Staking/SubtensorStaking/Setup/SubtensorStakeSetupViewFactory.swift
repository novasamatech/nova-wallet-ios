import Foundation
import Foundation_iOS
import UIKit
import BigInt

/// DI assembly for the Subtensor stake setup flow. Replaces the old
/// `SubtensorStakingViewFactory.createView(coldkey:)` entry point as the
/// destination of `StartStakingInfoSubtensorWireframe.showSetupAmount`.
///
/// Mirrors `ParaStkStakeSetupViewFactory` for dependency wiring:
///  - `WalletLocalSubscriptionFactory.shared` + `PriceProviderFactory.shared`
///    drive live balance + price updates
///  - `BalanceViewModelFactory` backs `AmountInputViewModel` / Max-button
///    percentage support
///  - `CurrencyManager.shared` + `localizationManager` applied on the VC
///
/// Returns nil if the selected wallet has no account for the chain.
enum SubtensorStakeSetupViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        netuid: UInt16 = SubtensorStakingConstants.rootNetuid,
        subnetName: String? = nil
    ) -> UIViewController? {
        let selectedWallet = SelectedWalletSettings.shared.value

        guard
            let selectedAccount = selectedWallet?
            .fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let walletName = selectedWallet?.name ?? ""

        let delegatesClient = BittensorDelegatesClient()

        // [TEMP-TAOSTATS] Phase B temporary numeric data source. When Nova's
        // infra team ships Bittensor indexer support the `if let key` branch
        // is deleted and a single `NovaIndexerValidatorDataSource()` is
        // instantiated instead — no other wiring changes.
        let dataSource: SubtensorValidatorDataSourceProtocol = {
            if let key = TaoStatsKeyProvider.loadKey() {
                return TaoStatsValidatorDataSource(apiKey: key, session: .shared)
            } else {
                return StubSubtensorValidatorDataSource()
            }
        }()

        let validatorProvider = SubtensorValidatorProvider(
            delegatesClient: delegatesClient,
            dataSource: dataSource
        )

        // Pull the chain's preferred RPC node so dev / staging configs
        // don't silently fall back to mainnet. Mirrors the resolution
        // already used by `SubtensorMultistakingUpdateService` and the
        // dashboard view factory.
        let rpcURL = chainAsset.chain.nodes
            .compactMap { URL(string: $0.url) }
            .first { $0.scheme == "https" || $0.scheme == "http" }
            ?? URL(string: "https://entrypoint-finney.opentensor.ai")!

        let service = SubtensorStakingService(
            validatorProvider: validatorProvider,
            selectedColdkey: selectedAccount.chainAccount.accountId,
            rpcURL: rpcURL
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let interactor = SubtensorStakeSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            service: service,
            validatorProvider: validatorProvider,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            currencyManager: currencyManager,
            netuid: netuid
        )

        let wireframe = SubtensorStakeSetupWireframe()

        let cellViewModelFactory = SubtensorValidatorCellViewModelFactory(
            stakeSymbol: chainAsset.asset.symbol,
            assetPrecision: chainAsset.asset.precision
        )

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizationManager = LocalizationManager.shared

        let presenter = SubtensorStakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            walletName: walletName,
            validatorProvider: validatorProvider,
            cellViewModelFactory: cellViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            netuid: netuid
        )

        let viewController = SubtensorStakeSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager,
            subnetName: subnetName
        )

        presenter.view = viewController
        interactor.presenter = presenter

        return viewController
    }
}
