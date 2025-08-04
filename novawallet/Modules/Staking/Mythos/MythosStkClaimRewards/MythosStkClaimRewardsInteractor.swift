import UIKit
import Operation_iOS
import Keystore_iOS

final class MythosStkClaimRewardsInteractor: AnyProviderAutoCleaning {
    weak var presenter: MythosStkClaimRewardsInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let rewardsSyncService: MythosStakingClaimableRewardsServiceProtocol
    let settingsManager: SettingsManagerProtocol

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var autoCompoundProvider: AnyDataProvider<DecodedPercent>?
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        extrinsicService: ExtrinsicServiceProtocol,
        submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        rewardsSyncService: MythosStakingClaimableRewardsServiceProtocol,
        settingsManager: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.submissionMonitor = submissionMonitor
        self.signingWrapper = signingWrapper
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.stakingDetailsService = stakingDetailsService
        self.rewardsSyncService = rewardsSyncService
        self.settingsManager = settingsManager
        self.logger = logger
        self.operationQueue = operationQueue

        self.currencyManager = currencyManager
    }
}

private extension MythosStkClaimRewardsInteractor {
    func makeAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)
        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainId,
            assetId: assetId
        )
    }

    func makePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func makeClaimableRewardsSubscription() {
        rewardsSyncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let newState {
                self?.presenter?.didReceiveClaimableRewards(newState)
            }
        }
    }

    func makeStakingDetailsSubscription() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, detailsState in
            guard case let .defined(details) = detailsState else {
                return
            }

            self?.presenter?.didReceiveStakingDetails(details)
        }
    }

    func makeAutoCompoundSubscription() {
        clear(dataProvider: &autoCompoundProvider)

        autoCompoundProvider = subscribeToAutoCompound(
            for: chainId,
            accountId: accountId
        )
    }

    func getExtrinsicBuilderClosure(for model: MythosStkClaimRewardsModel) -> ExtrinsicBuilderClosure {
        { builder in
            var currentBuilder = try builder.adding(
                call: MythosStakingPallet.ClaimRewardsCall().runtimeCall()
            )

            if let restake = model.getRestake() {
                currentBuilder = try currentBuilder
                    .adding(call: restake.lock.runtimeCall())
                    .adding(call: restake.stake.runtimeCall())
            }

            return currentBuilder
        }
    }

    func setupDataRetrieval() {
        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeClaimableRewardsSubscription()
        makeStakingDetailsSubscription()
        makeAutoCompoundSubscription()
    }

    func clearDataRetrieval() {
        clear(streamableProvider: &balanceProvider)
        clear(streamableProvider: &priceProvider)
        clear(dataProvider: &autoCompoundProvider)
        rewardsSyncService.remove(observer: self)
        stakingDetailsService.remove(observer: self)
    }

    func provideMythosRestakeState() {
        if settingsManager.isMythosRestakeEnabled {
            presenter?.didReceiveClaimStragegy(.restake)
        } else {
            presenter?.didReceiveClaimStragegy(.freeBalance)
        }
    }
}

extension MythosStkClaimRewardsInteractor: MythosStkClaimRewardsInteractorInputProtocol {
    func setup() {
        setupDataRetrieval()

        provideMythosRestakeState()
    }

    func save(claimStrategy: StakingClaimRewardsStrategy) {
        switch claimStrategy {
        case .restake:
            settingsManager.isMythosRestakeEnabled = true
        case .freeBalance:
            settingsManager.isMythosRestakeEnabled = false
        }
    }

    func estimateFee(for model: MythosStkClaimRewardsModel) {
        let closure = getExtrinsicBuilderClosure(for: model)

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.presenter?.didReceiveFeeResult(result)
        }
    }

    func submit(model: MythosStkClaimRewardsModel) {
        let closure = getExtrinsicBuilderClosure(for: model)

        let wrapper = submissionMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: closure,
            signer: signingWrapper
        )

        clearDataRetrieval()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            do {
                let model = try result.getSuccessSubmittedModel()
                self?.presenter?.didReceiveSubmissionResult(.success(model))
            } catch {
                self?.setupDataRetrieval()
                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}

extension MythosStkClaimRewardsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            presenter?.didReceiveAssetBalance(assetBalance)
        case let .failure(error):
            logger.error("Balance subscription: \(error)")
        }
    }
}

extension MythosStkClaimRewardsInteractor: MythosStakingLocalStorageSubscriber, MythosStakingLocalStorageHandler {
    func handleAutoCompound(
        result: Result<Percent?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(autoCompound):
            presenter?.didReceiveAutoCompound(autoCompound)
        case let .failure(error):
            logger.error("AutoCompound subscription: \(error)")
        }
    }
}

extension MythosStkClaimRewardsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription: \(error)")
        }
    }
}

extension MythosStkClaimRewardsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
