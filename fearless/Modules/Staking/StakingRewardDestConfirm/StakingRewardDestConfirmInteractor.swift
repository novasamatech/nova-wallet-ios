import UIKit
import RobinHood
import IrohaCrypto
import SoraKeystore

final class StakingRewardDestConfirmInteractor: AccountFetching {
    weak var presenter: StakingRewardDestConfirmInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?

    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signingWrapper: SigningWrapperProtocol?

    private lazy var callFactory = SubstrateCallFactory()

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.accountRepositoryFactory = accountRepositoryFactory
        self.feeProxy = feeProxy
    }

    private func setupExtrinsicService(_ response: MetaChainAccountResponse) {
        extrinsicService = extrinsicServiceFactory.createService(
            accountId: response.chainAccount.accountId,
            chainFormat: response.chainAccount.chainFormat,
            cryptoType: response.chainAccount.cryptoType
        )

        signingWrapper = extrinsicServiceFactory.createSigningWrapper(
            metaId: response.metaId,
            account: response.chainAccount
        )
    }
}

extension StakingRewardDestConfirmInteractor: StakingRewardDestConfirmInteractorInputProtocol {
    func setup() {
        if let address = try? selectedAccount.accountId.toAddress(using: chainAsset.chain.chainFormat) {
            stashItemProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceiveStashItem(result: .failure(CommonError.undefined))
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
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
        guard let extrinsicService = extrinsicService, let signingWrapper = signingWrapper else {
            presenter.didSubmitRewardDest(result: .failure(CommonError.undefined))
            return
        }

        do {
            let setPayeeCall = try callFactory.setRewardDestination(rewardDestination, stashItem: stashItem)

            extrinsicService.submit(
                { builder in
                    try builder.adding(call: setPayeeCall)
                },
                signer: signingWrapper,
                runningIn: .main
            ) { [weak self] result in
                self?.presenter.didSubmitRewardDest(result: result)
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
            clear(dataProvider: &accountInfoProvider)
            let stashItem = try result.get()

            let maybeController = try stashItem.map { try $0.controller.toAccountId() }

            if let controllerId = maybeController {
                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: controllerId,
                    chainId: chainAsset.chain.chainId
                )

                fetchFirstMetaAccountResponse(
                    for: controllerId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(accountResponse):
                        if let accountResponse = accountResponse {
                            self?.setupExtrinsicService(accountResponse)
                        }

                        let maybeAccountItem = try? accountResponse?.chainAccount.toAccountItem()

                        self?.presenter.didReceiveStashItem(result: .success(stashItem))
                        self?.presenter.didReceiveController(result: .success(maybeAccountItem))
                    case let .failure(error):
                        self?.presenter.didReceiveStashItem(result: .failure(error))
                        self?.presenter.didReceiveController(result: .failure(error))
                    }
                }
            } else {
                presenter.didReceiveStashItem(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
                presenter.didReceiveController(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveController(result: .success(nil))
            presenter.didReceiveAccountInfo(result: .failure(error))
        }
    }
}

extension StakingRewardDestConfirmInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: PriceLocalStorageSubscriber,
    PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRewardDestConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
