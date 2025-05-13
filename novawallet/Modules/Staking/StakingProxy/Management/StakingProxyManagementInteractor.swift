import UIKit
import SubstrateSdk
import Operation_iOS

final class StakingProxyManagementInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingProxyManagementInteractorOutputProtocol?

    let sharedState: RelaychainStakingSharedStateProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let selectedAccount: MetaChainAccountResponse
    private var chainAsset: ChainAsset { sharedState.stakingOption.chainAsset }
    private let operationQueue: OperationQueue

    var proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol {
        sharedState.proxyLocalSubscriptionFactory
    }

    private var proxyProvider: AnyDataProvider<DecodedProxyDefinition>?

    init(
        selectedAccount: MetaChainAccountResponse,
        sharedState: RelaychainStakingSharedStateProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.sharedState = sharedState
        self.identityProxyFactory = identityProxyFactory
        self.operationQueue = operationQueue
    }

    private func performProxySubscription() {
        clear(dataProvider: &proxyProvider)

        proxyProvider = subscribeProxies(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            modifyInternalList: ProxyFilter.filteredStakingProxy
        )
    }

    private func fetchIdentities(proxyDefifnition: ProxyDefinition?) {
        guard let proxyDefifnition = proxyDefifnition, !proxyDefifnition.definition.isEmpty else {
            return
        }

        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId(
            for: {
                proxyDefifnition.definition.map(\.proxy)
            }
        )

        execute(
            wrapper: identityWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] in
            switch $0 {
            case let .success(identities):
                self?.presenter?.didReceive(identities: identities)
            case let .failure(error):
                self?.presenter?.didReceive(error: .identities(error))
            }
        }
    }
}

extension StakingProxyManagementInteractor: StakingProxyManagementInteractorInputProtocol {
    func setup() {
        performProxySubscription()
    }
}

extension StakingProxyManagementInteractor: ProxyListLocalSubscriptionHandler, ProxyListLocalStorageSubscriber {
    func handleProxies(result: Result<ProxyDefinition?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(proxy):
            presenter?.didReceive(proxyDefinition: proxy)
            fetchIdentities(proxyDefifnition: proxy)
        case let .failure(error):
            presenter?.didReceive(error: .proxyDefifnition(error))
        }
    }
}
