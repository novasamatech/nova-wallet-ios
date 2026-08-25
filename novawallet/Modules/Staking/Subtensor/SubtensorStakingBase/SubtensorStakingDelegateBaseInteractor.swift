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
        self.identityProxyFactory = identityProxyFactory

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            positionsSyncService: positionsSyncService,
            rootClaimableService: rootClaimableService,
            preflightFactory: preflightFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
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
    func applyDelegate(with accountId: AccountId) {
        refreshPreflight(for: accountId)
    }
}
