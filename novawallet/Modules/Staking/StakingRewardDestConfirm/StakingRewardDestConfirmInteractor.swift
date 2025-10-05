import UIKit
import Operation_iOS
import NovaCrypto
import Keystore_iOS

final class StakingRewardDestConfirmInteractor: AccountFetching {
    weak var presenter: StakingRewardDestConfirmInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
        self.accountRepositoryFactory = accountRepositoryFactory
        self.feeProxy = feeProxy
        self.currencyManager = currencyManager
    }

    private func setupExtrinsicService(_ response: MetaChainAccountResponse) {
        let chain = chainAsset.chain

        let extrinsicService = extrinsicServiceFactory.createService(
            account: response.chainAccount,
            chain: chain
        )

        self.extrinsicService = extrinsicService

        extrinsicMonitorFactory = extrinsicServiceFactory.createExtrinsicSubmissionMonitor(
            with: extrinsicService
        )

        signingWrapper = signingWrapperFactory.createSigningWrapper(
            for: response.metaId,
            accountResponse: response.chainAccount
        )
    }
}

extension StakingRewardDestConfirmInteractor: StakingRewardDestConfirmInteractorInputProtocol {
    func setup() {
        if let address = try? selectedAccount.accountId.toAddress(using: chainAsset.chain.chainFormat) {
            stashItemProvider = subscribeStashItemProvider(for: address, chainId: chainAsset.chain.chainId)
        } else {
            presenter.didReceiveStashItem(result: .failure(CommonError.undefined))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        feeProxy.delegate = self
    }

    func estimateFee(for rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem) {
        guard let extrinsicService = extrinsicService else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        do {
            let setPayeeCall = try callFactory.setRewardDestination(rewardDestination, stashItem: stashItem)

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: setPayeeCall.callName
            ) { builder in
                try builder.adding(call: setPayeeCall)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func submit(rewardDestination: RewardDestination<AccountAddress>, for stashItem: StashItem) {
        guard let extrinsicMonitorFactory, let signingWrapper else {
            presenter.didSubmitRewardDest(result: .failure(CommonError.undefined))
            return
        }

        do {
            let setPayeeCall = try callFactory.setRewardDestination(rewardDestination, stashItem: stashItem)

            let builderClosure: ExtrinsicBuilderClosure = { builder in
                try builder.adding(call: setPayeeCall)
            }

            let wrapper = extrinsicMonitorFactory.submitAndMonitorWrapper(
                extrinsicBuilderClosure: builderClosure,
                signer: signingWrapper
            )

            execute(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                self?.presenter.didSubmitRewardDest(result: result.mapToExtrinsicSubmittedResult())
            }

        } catch {
            presenter.didSubmitRewardDest(result: .failure(error))
        }
    }
}

extension StakingRewardDestConfirmInteractor: StakingLocalStorageSubscriber,
    StakingLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(streamableProvider: &balanceProvider)
            let stashItem = try result.get()

            let maybeController = try stashItem.map { try $0.controller.toAccountId() }

            if let controllerId = maybeController {
                balanceProvider = subscribeToAssetBalanceProvider(
                    for: controllerId,
                    chainId: chainAsset.chain.chainId,
                    assetId: chainAsset.asset.assetId
                )

                fetchFirstMetaAccountResponse(
                    for: controllerId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationQueue: operationQueue
                ) { [weak self] result in
                    switch result {
                    case let .success(accountResponse):
                        if let accountResponse = accountResponse {
                            self?.setupExtrinsicService(accountResponse)
                        }

                        self?.presenter.didReceiveStashItem(result: .success(stashItem))
                        self?.presenter.didReceiveController(result: .success(accountResponse))
                    case let .failure(error):
                        self?.presenter.didReceiveStashItem(result: .failure(error))
                        self?.presenter.didReceiveController(result: .failure(error))
                    }
                }
            } else {
                presenter.didReceiveStashItem(result: .success(nil))
                presenter.didReceiveAccountBalance(result: .success(nil))
                presenter.didReceiveController(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveController(result: .success(nil))
            presenter.didReceiveAccountBalance(result: .failure(error))
        }
    }
}

extension StakingRewardDestConfirmInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        presenter.didReceiveAccountBalance(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: PriceLocalStorageSubscriber,
    PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter.didReceiveFee(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
