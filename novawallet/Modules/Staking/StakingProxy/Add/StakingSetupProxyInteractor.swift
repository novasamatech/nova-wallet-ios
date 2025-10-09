import UIKit
import Operation_iOS

final class StakingSetupProxyInteractor: StakingProxyBaseInteractor, AccountFetching {
    weak var presenter: StakingSetupProxyInteractorOutputProtocol? {
        basePresenter as? StakingSetupProxyInteractorOutputProtocol
    }

    let web3NamesService: Web3NameServiceProtocol?
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>

    init(
        web3NamesService: Web3NameServiceProtocol?,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        runtimeService: RuntimeCodingServiceProtocol,
        sharedState: RelaychainStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        selectedAccount: ChainAccountResponse,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.web3NamesService = web3NamesService
        self.accountRepository = accountRepository

        super.init(
            runtimeService: runtimeService,
            sharedState: sharedState,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            accountProviderFactory: accountProviderFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            callFactory: callFactory,
            feeProxy: feeProxy,
            extrinsicService: extrinsicService,
            selectedAccount: selectedAccount,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    override func setup() {
        super.setup()
        web3NamesService?.setup()
        fetchAccounts()
    }

    private func fetchAccounts() {
        fetchAllMetaAccountChainResponses(
            for: chainAsset.chain.accountRequest(),
            repository: accountRepository,
            operationQueue: operationQueue
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleFetchAccountsResult(result)
            }
        }
    }

    private func handleFetchAccountsResult(_ result: Result<[MetaAccountChainResponse], Error>) {
        switch result {
        case let .failure(error):
            presenter?.didReceive(error: .fetchMetaAccounts(error))
            presenter?.didReceive(yourWallets: [])
        case let .success(accounts):
            let excludedWalletTypes: [MetaAccountModelType] = [.watchOnly]
            let filteredAccounts = accounts.filter {
                !excludedWalletTypes.contains($0.metaAccount.type) && $0.chainAccountResponse != nil
            }
            presenter?.didReceive(yourWallets: filteredAccounts)
        }
    }
}

extension StakingSetupProxyInteractor: StakingSetupProxyInteractorInputProtocol {
    func search(web3Name: String) {
        guard let web3NamesService = web3NamesService else {
            let error = Web3NameServiceError.serviceNotFound(web3Name, chainAsset.chain.name)
            presenter?.didReceive(error: .web3Name(error))
            return
        }

        web3NamesService.cancel()
        web3NamesService.search(
            name: web3Name,
            destinationChainAsset: chainAsset
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(recipients):
                    self.presenter?.didReceive(recipients: recipients, for: web3Name)
                case let .failure(error):
                    self.presenter?.didReceive(error: .web3Name(error))
                }
            }
        }
    }

    func refetchAccounts() {
        fetchAccounts()
    }
}
