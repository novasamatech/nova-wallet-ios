import Foundation
import BigInt
import Operation_iOS

/// Interactor for the Subtensor stake setup flow. Surfaces:
///   - active-validator list + min-delegation runtime constant (from
///     `SubtensorStakingService`)
///   - live `AssetBalance` via `WalletLocalSubscriptionFactoryProtocol`
///   - live `PriceData` via `PriceProviderFactoryProtocol`
///   - extrinsic fee via `ExtrinsicFeeProxy` — re-estimates on validator
///     selection / amount change with real values, falls back to a
///     placeholder hotkey + 1 TAO before validator pick so the row
///     shows a fee from the moment the screen loads.
final class SubtensorStakeSetupInteractor {
    weak var presenter: SubtensorStakeSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let service: SubtensorStakingService
    let validatorProvider: SubtensorValidatorProvider
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let netuid: UInt16

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var setupTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        service: SubtensorStakingService,
        validatorProvider: SubtensorValidatorProvider,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        currencyManager: CurrencyManagerProtocol,
        netuid: UInt16 = SubtensorStakingConstants.rootNetuid
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.service = service
        self.validatorProvider = validatorProvider
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.netuid = netuid
        self.currencyManager = currencyManager
    }

    deinit {
        setupTask?.cancel()
        refreshTask?.cancel()
    }

    private func performAssetBalanceSubscription() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    private func performPriceSubscription() {
        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func fetchValidatorsAndMinDelegation() {
        setupTask?.cancel()
        setupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                async let validators = service.fetchActiveValidators(
                    netuid: netuid
                )
                async let minDelegation = service.fetchMinDelegation()

                let (fetchedValidators, fetchedMin) = try await(validators, minDelegation)
                guard !Task.isCancelled else { return }

                presenter?.didReceive(validators: fetchedValidators)
                presenter?.didReceive(minDelegation: fetchedMin)
            } catch {
                guard !Task.isCancelled else { return }
                presenter?.didReceive(error: error)
            }
        }
    }
}

// MARK: - SubtensorStakeSetupInteractorInputProtocol

extension SubtensorStakeSetupInteractor: SubtensorStakeSetupInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        performAssetBalanceSubscription()
        performPriceSubscription()
        fetchValidatorsAndMinDelegation()
        estimateFee(hotkey: nil, amount: nil)
    }

    /// Estimate add_stake_limit fee. Mirrors Confirm's pattern: pass the
    /// real selected hotkey + typed amount when available, fall back to
    /// placeholders (zero hotkey, 1 TAO) so the row shows a fee before
    /// the user has picked a validator.
    func estimateFee(hotkey: AccountId?, amount: BigUInt?) {
        let actualHotkey = hotkey ?? AccountId(repeating: 0, count: 32)
        let actualAmount = amount ?? 1_000_000_000 // 1 TAO representative
        let runtimeCall = SubtensorExtrinsicBuilder.buildAddStakeLimit(
            hotkey: actualHotkey,
            netuid: netuid,
            amount: actualAmount,
            slippage: SubtensorStakingConstants.defaultSlippage
        )
        let identifier = "stake-setup-\(netuid)-\(actualHotkey.toHex())-\(actualAmount)"

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: { builder in
                try builder.adding(call: runtimeCall)
            }
        )
    }

    func refreshValidators() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let validators = try await service.fetchActiveValidators(
                    netuid: netuid
                )
                guard !Task.isCancelled else { return }
                presenter?.didReceive(validators: validators)
            } catch {
                guard !Task.isCancelled else { return }
                presenter?.didReceive(error: error)
            }
        }
    }
}

// MARK: - Wallet subscription

extension SubtensorStakeSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

// MARK: - Price subscription

extension SubtensorStakeSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

// MARK: - Fee proxy delegate

extension SubtensorStakeSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(fee):
            presenter?.didReceive(fee: fee)
        case let .failure(error):
            presenter?.didReceive(fee: nil)
            presenter?.didReceive(error: error)
        }
    }
}

// MARK: - Currency observation

extension SubtensorStakeSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, chainAsset.asset.priceId != nil else { return }
        performPriceSubscription()
    }
}
