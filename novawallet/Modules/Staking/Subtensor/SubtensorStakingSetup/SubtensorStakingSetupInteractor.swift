import UIKit
import SubstrateSdk
import Operation_iOS

final class SubtensorStakingSetupInteractor: SubtensorStakingDelegateBaseInteractor {
    var presenter: SubtensorStakingSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorStakingSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let initialNetuid: UInt16?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        rootClaimableService: SubtensorRootClaimableServiceProtocol,
        preflightFactory: SubtensorPreflightFactoryProtocol,
        tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol,
        operationService: SubtensorStakingOperationServiceProtocol,
        rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        initialNetuid: UInt16?,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.rewardCalculatorService = rewardCalculatorService
        self.subnetsService = subnetsService
        self.initialNetuid = initialNetuid

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            positionsSyncService: positionsSyncService,
            rootClaimableService: rootClaimableService,
            preflightFactory: preflightFactory,
            tradeQuoteFactory: tradeQuoteFactory,
            operationService: operationService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            runtimeProvider: runtimeProvider,
            identityProxyFactory: identityProxyFactory,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    override func onSetup() {
        super.onSetup()

        provideRewardEngine()
        provideInitialSubnet()
    }
}

private extension SubtensorStakingSetupInteractor {
    func provideRewardEngine() {
        rewardCalculatorService.fetchEngine(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(engine):
                self?.presenter?.didReceiveRewardEngine(engine)
            case let .failure(error):
                // the estimated-earnings row stays hidden rather than showing a guess
                self?.logger.error("Root APY unavailable: \(error)")
                self?.presenter?.didReceiveRewardEngine(nil)
            }
        }
    }

    func provideInitialSubnet() {
        guard let initialNetuid, initialNetuid != SubtensorStakingPallet.rootNetuid else { return }
        subnetsService.fetchSubnetsInfo(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(info): self?.presenter?.didReceiveInitialSubnets(info)
            case let .failure(error): self?.presenter?.didFailInitialSubnets(error)
            }
        }
    }
}

extension SubtensorStakingSetupInteractor: SubtensorStakingSetupInteractorInputProtocol {
    func retryInitialSubnet() {
        provideInitialSubnet()
    }
}
