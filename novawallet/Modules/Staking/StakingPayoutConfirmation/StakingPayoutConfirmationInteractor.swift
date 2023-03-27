import Foundation
import SoraKeystore
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

final class StakingPayoutConfirmationInteractor {
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: MultiExtrinsicFeeProxyProtocol
    let chainRegistry: ChainRegistryProtocol
    let signer: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?
    let payouts: [PayoutInfo]

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        chainRegistry: ChainRegistryProtocol,
        signer: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol,
        payouts: [PayoutInfo],
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.chainRegistry = chainRegistry
        self.signer = signer
        self.operationManager = operationManager
        self.payouts = payouts
        self.logger = logger
        self.currencyManager = currencyManager
    }

    // MARK: - Private functions

    private func createExtrinsicSplitter(for payouts: [PayoutInfo]) throws -> ExtrinsicSplitting {
        let callFactory = SubstrateCallFactory()

        var splitter = ExtrinsicSplitter(chain: chainAsset.chain, chainRegistry: chainRegistry)

        splitter = try payouts.reduce(splitter) { accum, payout in
            let payoutCall = try callFactory.payout(
                validatorId: payout.validator,
                era: payout.era
            )

            return accum.adding(call: payoutCall)
        }

        return splitter
    }

    private func provideRewardAmount() {
        let rewardAmount = payouts.map(\.reward).reduce(0, +)

        presenter?.didRecieve(account: selectedAccount, rewardAmount: rewardAmount)
    }
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePriceData(result: .success(nil))
        }

        provideRewardAmount()

        estimateFee()
    }

    func submitPayout() {
        do {
            presenter?.didStartPayout()

            let splitter = try createExtrinsicSplitter(for: payouts)

            extrinsicService.submitWithTxSplitter(
                splitter,
                signer: signer,
                runningIn: .main
            ) { [weak self] submission in
                do {
                    let txHashes = try submission.results.map { try $0.result.get() }
                    self?.presenter?.didCompletePayout(txHashes: txHashes)
                } catch {
                    self?.presenter?.didFailPayout(error: error)
                }
            }
        } catch {
            presenter?.didFailPayout(error: error)
        }
    }

    func estimateFee() {
        do {
            let splitter = try createExtrinsicSplitter(for: payouts)
            let identifier = "\(payouts.hashValue)"

            feeProxy.estimateFee(
                from: splitter,
                service: extrinsicService,
                reuseIdentifier: identifier
            )

        } catch {
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}

extension StakingPayoutConfirmationInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter?.didReceiveAccountBalance(result: result)
    }
}

extension StakingPayoutConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result)
    }
}

extension StakingPayoutConfirmationInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}

extension StakingPayoutConfirmationInteractor: MultiExtrinsicFeeProxyDelegate {
    func didReceiveTotalFee(result: Result<BigUInt, Error>, for _: TransactionFeeId) {
        let decimalResult = result.map { value in
            Decimal.fromSubstrateAmount(value, precision: chainAsset.assetDisplayInfo.assetPrecision) ?? 0
        }

        presenter?.didReceiveFee(result: decimalResult)
    }
}
