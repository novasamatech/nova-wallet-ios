import Foundation
import Operation_iOS
import Foundation_iOS

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    private func continueSetup() {
        applicationHandler.delegate = self

        guard let chain = crowdloanState.settings.value else {
            presenter?.didReceiveSelectedChain(result: .failure(
                PersistentValueSettingsError.missingValue
            ))
            return
        }

        let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId

        setup(with: accountId, chain: chain)
        becomeOnline(with: chain)
    }

    func setup() {
        setupState { [weak self] _ in
            self?.continueSetup()
        }
    }

    func refresh() {
        guard let chain = crowdloanState.settings.value else {
            presenter?.didReceiveSelectedChain(result: .failure(
                PersistentValueSettingsError.missingValue
            ))
            return
        }

        refresh(with: chain)
    }

    func saveSelected(chainModel: ChainModel) {
        if crowdloanState.settings.value?.chainId != chainModel.chainId {
            clear()

            crowdloanState.settings.save(value: chainModel, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case .success:
                    self?.handleSelectionChange(to: chainModel)
                case let .failure(error):
                    self?.presenter?.didReceiveSelectedChain(result: .failure(error))
                }
            }
        }
    }

    func becomeOnline() {
        guard let chain = crowdloanState.settings.value else {
            return
        }

        becomeOnline(with: chain)
    }

    func putOffline() {
        guard let chain = crowdloanState.settings.value else {
            return
        }

        putOffline(with: chain)
    }
}

extension CrowdloanListInteractor: CrowdloanLocalStorageSubscriber, CrowdloanLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    var crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol {
        crowdloanState.crowdloanLocalSubscriptionFactory
    }

    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId: ChainModel.Id) {
        if let chain = crowdloanState.settings.value, chain.chainId == chainId {
            provideCrowdloans(for: chain)
            presenter?.didReceiveBlockNumber(result: result)
        }
    }
}

extension CrowdloanListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        if
            let chain = crowdloanState.settings.value,
            chain.utilityChainAssetId() == ChainAssetId(chainId: chainId, assetId: assetId) {
            logger?.debug("Did receive balance for accountId: \(accountId.toHex()))")

            presenter?.didReceiveAccountBalance(result: result)
        }
    }
}

extension CrowdloanListInteractor: CrowdloanOffchainSubscriber, CrowdloanOffchainSubscriptionHandler {
    var crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol {
        crowdloanState.crowdloanOffchainProviderFactory
    }

    func handleExternalContributions(
        result: Result<[ExternalContribution]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(maybeContributions):
            presenter?.didReceiveExternalContributions(result: .success(maybeContributions ?? []))
        case let .failure(error):
            presenter?.didReceiveExternalContributions(result: .failure(error))
        }
    }
}

extension CrowdloanListInteractor: ApplicationHandlerDelegate {
    func didReceiveDidEnterBackground(notification _: Notification) {
        cancelCrowdloansOnchainRequests()
    }
}
