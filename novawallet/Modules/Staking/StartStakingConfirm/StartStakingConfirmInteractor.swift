import UIKit
import Operation_iOS
import BigInt

class StartStakingConfirmInteractor: AnyProviderAutoCleaning {
    weak var presenter: StartStakingConfirmInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let stakingAmount: BigUInt
    let stakingOption: SelectedStakingOption
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicFeeProxy: ExtrinsicFeeProxyProtocol
    let signingWrapper: SigningWrapperProtocol
    let extrinsicSubmissionProxy: StartStakingExtrinsicProxyProtocol
    let restrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let sharedOperation: SharedOperationProtocol?

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?

    init(
        stakingAmount: BigUInt,
        stakingOption: SelectedStakingOption,
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicFeeProxy: ExtrinsicFeeProxyProtocol,
        restrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        extrinsicSubmissionProxy: StartStakingExtrinsicProxyProtocol,
        signingWrapper: SigningWrapperProtocol,
        sharedOperation: SharedOperationProtocol?,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.stakingAmount = stakingAmount
        self.stakingOption = stakingOption
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicSubmissionProxy = extrinsicSubmissionProxy
        self.extrinsicService = extrinsicService
        self.extrinsicFeeProxy = extrinsicFeeProxy
        self.restrictionsBuilder = restrictionsBuilder
        self.signingWrapper = signingWrapper
        self.sharedOperation = sharedOperation
        self.currencyManager = currencyManager
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func performAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let chainAssetId = chainAsset.chainAssetId

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }
}

extension StartStakingConfirmInteractor: StartStakingConfirmInteractorInputProtocol {
    func setup() {
        extrinsicFeeProxy.delegate = self
        restrictionsBuilder.delegate = self

        performAssetBalanceSubscription()
        performPriceSubscription()

        restrictionsBuilder.start()

        estimateFee()
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
    }

    func retryRestrinctions() {
        restrictionsBuilder.stop()
        restrictionsBuilder.start()
    }

    func estimateFee() {
        extrinsicSubmissionProxy.estimateFee(
            using: extrinsicService,
            feeProxy: extrinsicFeeProxy,
            stakingOption: stakingOption,
            amount: stakingAmount
        )
    }

    func submit() {
        sharedOperation?.markSent()

        extrinsicSubmissionProxy.submit(
            using: extrinsicService,
            signer: signingWrapper,
            stakingOption: stakingOption,
            amount: stakingAmount
        ) { [weak self] result in
            switch result {
            case let .success(submittedModel):
                self?.presenter?.didReceiveConfirmation(model: submittedModel)
            case let .failure(error):
                self?.sharedOperation?.markComposing()
                self?.presenter?.didReceive(error: .confirmation(error))
            }
        }
    }
}

extension StartStakingConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(info):
            presenter?.didReceive(fee: info)
        case let .failure(error):
            presenter?.didReceive(error: .fee(error))
        }
    }
}

extension StartStakingConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == chainAsset.chain.chainId,
            assetId == chainAsset.asset.assetId,
            accountId == selectedAccount.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            let balance = balance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )

            presenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            presenter?.didReceive(error: .assetBalance(error))
        }
    }
}

extension StartStakingConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceive(price: priceData)
            case let .failure(error):
                presenter?.didReceive(error: .price(error))
            }
        }
    }
}

extension StartStakingConfirmInteractor: RelaychainStakingRestrictionsBuilderDelegate {
    func restrictionsBuilder(
        _: RelaychainStakingRestrictionsBuilding,
        didReceive error: Error
    ) {
        presenter?.didReceive(error: .restrictions(error))
    }

    func restrictionsBuilder(
        _: RelaychainStakingRestrictionsBuilding,
        didPrepare restrictions: RelaychainStakingRestrictions
    ) {
        presenter?.didReceive(restrictions: restrictions)
    }
}

extension StartStakingConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
