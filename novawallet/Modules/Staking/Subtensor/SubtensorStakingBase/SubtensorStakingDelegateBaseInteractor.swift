import UIKit
import SubstrateSdk
import Operation_iOS

class SubtensorStakingDelegateBaseInteractor: SubtensorStakingBaseInteractor {
    var delegatePresenter: SubtensorStakingDelegateInteractorOutputProtocol? {
        basePresenter as? SubtensorStakingDelegateInteractorOutputProtocol
    }

    let identityProxyFactory: IdentityProxyFactoryProtocol

    private let identityCancellable = CancellableCallStore()

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        rootClaimableService: SubtensorRootClaimableServiceProtocol,
        preflightFactory: SubtensorPreflightFactoryProtocol,
        tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol,
        operationService: SubtensorStakingOperationServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.identityProxyFactory = identityProxyFactory

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
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    deinit {
        identityCancellable.cancel()
    }

    override func onPositions(_ state: Multistaking.SubtensorStakingState?) {
        super.onPositions(state)

        let hotkeys = (state?.positions ?? []).map(\.hotkey)

        if !hotkeys.isEmpty {
            provideIdentities(for: Array(Set(hotkeys)))
        }
    }
}

private extension SubtensorStakingDelegateBaseInteractor {
    func provideIdentities(for hotkeys: [AccountId]) {
        identityCancellable.cancel()

        let wrapper = identityProxyFactory.createIdentityWrapperByAccountId(for: { hotkeys })

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: identityCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(identities):
                self?.delegatePresenter?.didReceiveDelegateIdentities(identities)
            case let .failure(error):
                self?.logger.error("Identities error: \(error)")
            }
        }
    }
}

extension SubtensorStakingDelegateBaseInteractor: SubtensorStakingDelegateInteractorInputProtocol {
    func applyDelegate(with accountId: AccountId, netuid: UInt16) {
        refreshPreflight(for: accountId, netuid: netuid)
    }
}
