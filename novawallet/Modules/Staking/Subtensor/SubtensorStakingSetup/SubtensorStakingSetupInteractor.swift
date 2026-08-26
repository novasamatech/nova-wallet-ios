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

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        rootClaimableService: SubtensorRootClaimableServiceProtocol,
        preflightFactory: SubtensorPreflightFactoryProtocol,
        quoteFactory: SubtensorQuoteOperationFactoryProtocol,
        rewardCalculatorService: SubtensorRewardCalculatorServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.rewardCalculatorService = rewardCalculatorService

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            positionsSyncService: positionsSyncService,
            rootClaimableService: rootClaimableService,
            preflightFactory: preflightFactory,
            quoteFactory: quoteFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
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
}

extension SubtensorStakingSetupInteractor: SubtensorStakingSetupInteractorInputProtocol {}
