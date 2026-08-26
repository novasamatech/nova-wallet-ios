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
        quoteFactory: SubtensorQuoteOperationFactoryProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
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
        self.subnetsService = subnetsService

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

    deinit {
        positionsSyncService.remove(failureObserver: self)
    }

    override func onSetup() {
        super.onSetup()

        provideSubnetsInfo()
        makePositionsFailureSubscription()
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

    /// the positions observable replays its last good value on a failed resync, so the parallel
    /// failure signal is the only way the unstake basis can tell fresh from stale (spec §3.2)
    func makePositionsFailureSubscription() {
        positionsSyncService.add(
            failureObserver: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.presenter?.didReceivePositionsSyncFailed(isFailed)
        }
    }
}

extension SubtensorUnstakeSetupInteractor: SubtensorUnstakeSetupInteractorInputProtocol {
    func retrySubnetsInfo() {
        provideSubnetsInfo()
    }

    func refreshPositions() {
        positionsSyncService.refresh()
    }
}
