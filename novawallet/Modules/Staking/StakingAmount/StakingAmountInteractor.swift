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
    let networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let operationManager: OperationManagerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    private var bagListSizeProvider: AnyDataProvider<DecodedU32>?

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
        networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        currencyManager: CurrencyManagerProtocol
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
        self.networkInfoOperationFactory = networkInfoOperationFactory
        self.eraValidatorService = eraValidatorService
        self.operationManager = operationManager
        self.currencyManager = currencyManager
    }

    private func provideNetworkInfo() {
        let wrapper = networkInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            do {
                let info = try wrapper.targetOperation.extractNoCancellableResultData()
                self?.presenter.didReceive(networkInfo: info)
            } catch {
                self?.presenter.didReceive(error: error)
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
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

    private func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        coderFactory: RuntimeCoderFactoryProtocol
    ) {
        guard let accountAddress = rewardDestination.accountAddress else {
            return
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let controller = try address.toAccountId()
            let payee = try Staking.RewardDestinationArg(rewardDestination: accountAddress)

            let bondClosure = try Staking.Bond.appendCall(
                for: .accoundId(controller),
                value: amount,
                payee: payee,
                codingFactory: coderFactory
            )

            let callFactory = SubstrateCallFactory()

            let targets = Array(
                repeating: SelectedValidatorInfo(address: address),
                count: SubstrateConstants.maxNominations
            )
            let nominateCall = try callFactory.nominate(targets: targets)

            return try bondClosure(builder).adding(call: nominateCall)
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

extension StakingAmountInteractor: StakingAmountInteractorInputProtocol, RuntimeConstantFetching,
    AccountFetching {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceive(price: nil)
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        minBondProvider = subscribeToMinNominatorBond(for: chainAsset.chain.chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainAsset.chain.chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainAsset.chain.chainId)
        bagListSizeProvider = subscribeBagsListSize(for: chainAsset.chain.chainId)

        provideRewardCalculator()
        provideNetworkInfo()

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
                self?.presenter.didReceive(accounts: responses)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }

    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>
    ) {
        runtimeService.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                self?.estimateFee(
                    for: address,
                    amount: amount,
                    rewardDestination: rewardDestination,
                    coderFactory: coderFactory
                )
            }, errorClosure: { [weak self] error in
                self?.presenter.didReceive(error: error)
            }
        )
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

    func handleBagListSize(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            presenter?.didReceive(bagListSize: value)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}

extension StakingAmountInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            presenter.didReceive(balance: assetBalance)
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

extension StakingAmountInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
