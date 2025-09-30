import Foundation
import Keystore_iOS

import Operation_iOS
import NovaCrypto
import BigInt

final class StakingPayoutConfirmationInteractor {
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: MultiExtrinsicFeeProxyProtocol
    let chainRegistry: ChainRegistryProtocol
    let signer: SigningWrapperProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?
    let payouts: [Staking.PayoutInfo]

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?

    private var codingFactory: RuntimeCoderFactoryProtocol?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        chainRegistry: ChainRegistryProtocol,
        signer: SigningWrapperProtocol,
        operationQueue: OperationQueue,
        payouts: [Staking.PayoutInfo],
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.chainRegistry = chainRegistry
        self.signer = signer
        self.operationQueue = operationQueue
        self.payouts = payouts
        self.logger = logger
        self.currencyManager = currencyManager
    }

    // MARK: - Private functions

    private func createExtrinsicSplitter(for payouts: [Staking.PayoutInfo]) throws -> ExtrinsicSplitting {
        guard let codingFactory = codingFactory else {
            throw CommonError.dataCorruption
        }

        var splitter: ExtrinsicSplitting = ExtrinsicSplitter(
            chain: chainAsset.chain,
            maxCallsPerExtrinsic: selectedAccount.chainAccount.type.maxCallsPerExtrinsic,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        splitter = try payouts.reduce(splitter) { accum, payout in
            try Staking.PayoutCall.appendingCall(
                for: payout.validator,
                era: payout.era,
                pages: payout.pages,
                codingFactory: codingFactory,
                builder: accum
            )
        }

        return splitter
    }

    private func provideRewardAmount() {
        let rewardAmount = payouts.map(\.reward).reduce(0, +)

        presenter?.didRecieve(account: selectedAccount, rewardAmount: rewardAmount)
    }

    private func continueSetup() {
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
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        runtimeService.fetchCoderFactory(
            runningIn: OperationManager(operationQueue: operationQueue),
            completion: { [weak self] codingFactory in
                self?.codingFactory = codingFactory
                self?.continueSetup()
            },
            errorClosure: { [weak self] error in
                self?.logger?.error("Unexpected error: \(error)")
            }
        )
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
                    let senders = try submission.results.map { try $0.result.get().sender }

                    guard let sender = senders.first else {
                        return
                    }

                    self?.presenter?.didCompletePayout(by: sender)
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
                reuseIdentifier: identifier,
                payingIn: chainAsset.chainAssetId
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
    func didReceiveTotalFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter?.didReceiveFee(result: result)
    }
}
