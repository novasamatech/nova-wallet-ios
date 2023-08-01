import UIKit
import RobinHood
import BigInt

final class StakingSetupAmountInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: StakingSetupAmountInteractorOutputProtocol?

    let selectedChainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let rewardService: RewardCalculatorServiceProtocol
    let networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)
    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var balanceProvider: StreamableProvider<AssetBalance>?
    private(set) var selectedAccount: ChainAccountResponse
    private(set) var operationQueue: OperationQueue

    private var rewardCalculatorOperation: CancellableCall?
    private var networkInfoCall: CancellableCall?
    private var minBondProvider: AnyDataProvider<DecodedBigUInt>?
    private var counterForNominatorsProvider: AnyDataProvider<DecodedU32>?
    private var maxNominatorsCountProvider: AnyDataProvider<DecodedU32>?
    private var bagListSizeProvider: AnyDataProvider<DecodedU32>?
    private var directStakingInfo: DirectStakingInfo = .init()

    init(
        selectedAccount: ChainAccountResponse,
        selectedChainAsset: ChainAsset,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        rewardService: RewardCalculatorServiceProtocol,
        networkInfoOperationFactory: NetworkStakingInfoOperationFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.selectedChainAsset = selectedChainAsset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeProvider = runtimeProvider
        self.extrinsicService = extrinsicService
        self.operationQueue = operationQueue
        self.rewardService = rewardService
        self.networkInfoOperationFactory = networkInfoOperationFactory
        self.eraValidatorService = eraValidatorService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    deinit {
        clear(streamableProvider: &priceProvider)
        clear(streamableProvider: &balanceProvider)
        clear(cancellable: &networkInfoCall)
        clear(cancellable: &rewardCalculatorOperation)
        clear(dataProvider: &minBondProvider)
        clear(dataProvider: &counterForNominatorsProvider)
        clear(dataProvider: &maxNominatorsCountProvider)
        clear(dataProvider: &bagListSizeProvider)
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = selectedChainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func performAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let chainAssetId = selectedChainAsset.chainAssetId

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    private func provideNetworkInfo() {
        clear(cancellable: &networkInfoCall)

        let wrapper = networkInfoOperationFactory.networkStakingOperation(
            for: eraValidatorService,
            runtimeService: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.networkInfoCall === wrapper else {
                    return
                }
                self?.networkInfoCall = nil
                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.directStakingInfo.networkInfo = info
                } catch {
                    self?.presenter?.didReceive(error: .networkInfo(error))
                }
            }
        }

        networkInfoCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideRewardCalculator() {
        clear(cancellable: &rewardCalculatorOperation)

        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.rewardCalculatorOperation === operation else {
                    return
                }

                self?.rewardCalculatorOperation = nil
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.directStakingInfo.calculator = engine
                } catch {
                    self?.presenter?.didReceive(error: .calculator(error))
                }
            }
        }

        rewardCalculatorOperation = operation
        operationQueue.addOperation(operation)
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
                self?.presenter?.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.presenter?.didReceive(error: .fee(error))
            }
        }
    }

    private func performMinBondSubscription() {
        clear(dataProvider: &minBondProvider)
        minBondProvider = subscribeToMinNominatorBond(for: selectedChainAsset.chain.chainId)
    }

    private func performCounterForNominatorsSubscription() {
        clear(dataProvider: &counterForNominatorsProvider)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: selectedChainAsset.chain.chainId)
    }

    private func performMaxNominatorsCountSubscription() {
        clear(dataProvider: &maxNominatorsCountProvider)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: selectedChainAsset.chain.chainId)
    }

    private func performBagsListSizeSubscription() {
        clear(dataProvider: &bagListSizeProvider)
        bagListSizeProvider = subscribeBagsListSize(for: selectedChainAsset.chain.chainId)
    }

    private func provideExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeProvider,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(amount):
                self?.presenter?.didReceive(minimalBalance: amount)
            case let .failure(error):
                self?.presenter?.didReceive(error: .existensialDeposit(error))
            }
        }
    }
}

extension StakingSetupAmountInteractor: StakingSetupAmountInteractorInputProtocol, RuntimeConstantFetching {
    func setup() {
        performAssetBalanceSubscription()
        performPriceSubscription()
        performMinBondSubscription()
        performCounterForNominatorsSubscription()
        performMaxNominatorsCountSubscription()
        performBagsListSizeSubscription()

        provideRewardCalculator()
        provideNetworkInfo()
        provideExistentialDeposit()
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
        performMinBondSubscription()
        performCounterForNominatorsSubscription()
        performMaxNominatorsCountSubscription()
        performBagsListSizeSubscription()
    }

    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>
    ) {
        runtimeProvider.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                self?.estimateFee(
                    for: address,
                    amount: amount,
                    rewardDestination: rewardDestination,
                    coderFactory: coderFactory
                )
            }, errorClosure: { [weak self] error in
                self?.presenter?.didReceive(error: .fetchCoderFactory(error))
            }
        )
    }

    func stakingTypeRecomendation(for amount: Decimal) {
        guard amount > 0 else {
            return
        }
        // TODO:
        presenter?.didReceive(stakingType: .direct(directStakingInfo))
    }
}

extension StakingSetupAmountInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == selectedChainAsset.chain.chainId,
            assetId == selectedChainAsset.asset.assetId,
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

extension StakingSetupAmountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if selectedChainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceive(price: priceData)
            case let .failure(error):
                presenter?.didReceive(error: .price(error))
            }
        }
    }
}

extension StakingSetupAmountInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            directStakingInfo.minNominatorBond = value
        case let .failure(error):
            presenter?.didReceive(error: .minNominatorBond(error))
        }
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            directStakingInfo.counterForNominators = value
        case let .failure(error):
            presenter?.didReceive(error: .counterForNominators(error))
        }
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            directStakingInfo.maxNominatorsCount = value
        case let .failure(error):
            presenter?.didReceive(error: .maxNominatorsCount(error))
        }
    }

    func handleBagListSize(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            directStakingInfo.bagListSize = value
        case let .failure(error):
            presenter?.didReceive(error: .bagListSize(error))
        }
    }
}

extension StakingSetupAmountInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = selectedChainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
