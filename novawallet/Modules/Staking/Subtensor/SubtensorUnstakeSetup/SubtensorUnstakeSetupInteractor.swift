import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorUnstakeSetupInteractor: SubtensorStakingDelegateBaseInteractor {
    var presenter: SubtensorUnstakeSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorUnstakeSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let subnetsService: SubtensorSubnetsServiceProtocol

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        rootClaimableService: SubtensorRootClaimableServiceProtocol,
        preflightFactory: SubtensorPreflightFactoryProtocol,
        tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol,
        operationService: SubtensorStakingOperationServiceProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.subnetsService = subnetsService

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

        provideSubnetsInfo()
    }
}

private extension SubtensorUnstakeSetupInteractor {
    func provideSubnetsInfo() {
        subnetsService.fetchSubnetsInfo(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceiveSubnetsInfo(info)
            case let .failure(error):
                self?.presenter?.didReceiveSubnetsInfoError(error)
            }
        }
    }
}

extension SubtensorUnstakeSetupInteractor: SubtensorUnstakeSetupInteractorInputProtocol {
    func retrySubnetsInfo() {
        provideSubnetsInfo()
    }
}
