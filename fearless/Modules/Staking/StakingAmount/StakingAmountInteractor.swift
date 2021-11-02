import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto
import BigInt
import SubstrateSdk

final class StakingAmountInteractor {
    weak var presenter: StakingAmountInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let repository: AnyDataProviderRepository<MetaAccountModel>
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let rewardService: RewardCalculatorServiceProtocol
    let operationManager: OperationManagerProtocol

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.repository = repository
        self.extrinsicService = extrinsicService
        self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
    }

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceive(calculator: engine)
                } catch {
                    self?.presenter.didReceive(calculatorError: error)
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }
}

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol, RuntimeConstantFetching,
    AccountFetching {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceive(price: nil)
        }

        balanceProvider = subscribeToAccountInfoProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId
        )

        minBondProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainAsset.chain.chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainAsset.chain.chainId)

        provideRewardCalculator()

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(amount):
                self?.presenter.didReceive(minimalBalance: amount)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }

    func fetchAccounts() {
        fetchAllMetaAccountResponses(
            for: chainAsset.chain.accountRequest(),
            repository: repository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(responses):
                let accountItems = responses.compactMap { try? $0.chainAccount.toAccountItem() }
                self?.presenter.didReceive(accounts: accountItems)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }

    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<AccountItem>
    ) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let bondCall = try callFactory.bond(
                amount: amount,
                controller: address,
                rewardDestination: rewardDestination.accountAddress
            )

            let targets = Array(
                repeating: SelectedValidatorInfo(address: address),
                count: SubstrateConstants.maxNominations
            )
            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: bondCall)
                .adding(call: nominateCall)
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(
                    paymentInfo: info,
                    for: amount,
                    rewardDestination: rewardDestination
                )
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }
}

extension StakingAmountInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            presenter.didReceive(minBondAmount: value)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            presenter.didReceive(counterForNominators: value)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            presenter.didReceive(maxNominatorsCount: value)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }
}

extension StakingAmountInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(accountInfo):
            presenter.didReceive(balance: accountInfo?.data)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }
}

extension StakingAmountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter.didReceive(price: priceData)
        case let .failure(error):
            presenter.didReceive(error: error)
        }
    }
}
