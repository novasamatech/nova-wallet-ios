import Foundation
import SubstrateSdk
import BigInt
import Operation_iOS

final class SubtensorUnstakeSetupInteractor {
    weak var presenter: SubtensorUnstakeSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let position: SubtensorStakePosition
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?
    private var spotPriceTaoPerAlpha: Double?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        position: SubtensorStakePosition,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.position = position
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func subscribePriceIfNeeded() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceive(price: nil)
        }
    }

    private func fetchAMMPriceIfNeeded() {
        guard position.netuid != SubtensorStakingConstants.rootNetuid else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let reserves = try await SubtensorSubnetFetcher.fetchSubnetReserves(
                    netuid: self.position.netuid
                )
                if reserves.alphaInReserve > 0 {
                    self.spotPriceTaoPerAlpha = Double(reserves.taoReserve) / Double(reserves.alphaInReserve)
                }
                // Re-estimate fee with the AMM price now available so limit_price
                // matches what confirm will submit.
                self.estimateFeeForFullPosition()
            } catch {
                Logger.shared.error("SubtensorUnstakeSetup: AMM price fetch failed — \(error)")
            }
        }
    }

    private func estimateFeeForFullPosition() {
        // Estimate fee with the full position amount as a representative value.
        // The actual confirm will re-estimate with the user's chosen amount.
        let runtimeCall = SubtensorExtrinsicBuilder.buildRemoveStakeLimit(
            hotkey: position.hotkey,
            netuid: position.netuid,
            amount: position.amount,
            slippage: SubtensorStakingConstants.defaultSlippage,
            spotPriceTaoPerAlpha: spotPriceTaoPerAlpha
        )

        let identifier = "unstake-setup-" + position.hotkey.toHex() + "-\(position.netuid)"

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: { builder in
                try builder.adding(call: runtimeCall)
            }
        )
    }
}

extension SubtensorUnstakeSetupInteractor: SubtensorUnstakeSetupInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        subscribePriceIfNeeded()
        estimateFeeForFullPosition()
        fetchAMMPriceIfNeeded()
    }
}

extension SubtensorUnstakeSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
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

extension SubtensorUnstakeSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(fee):
            presenter?.didReceive(fee: fee)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

extension SubtensorUnstakeSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, let priceId = chainAsset.asset.priceId else {
            return
        }
        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
