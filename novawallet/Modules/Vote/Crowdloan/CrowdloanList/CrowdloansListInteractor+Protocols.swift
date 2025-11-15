import Foundation
import Operation_iOS
import Foundation_iOS

private extension CrowdloanListInteractor {
    func continueSetup() {
        guard let chain = crowdloanState.settings.value else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId

        setup(with: accountId, chain: chain)
        becomeOnline(with: chain)
    }
}

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    func setup() {
        setupState { [weak self] _ in
            self?.continueSetup()
        }

        eventCenter.add(observer: self)
    }

    func saveSelected(chainModel: ChainModel) {
        if crowdloanState.settings.value?.chainId != chainModel.chainId {
            clear()

            crowdloanState.settings.save(value: chainModel, runningCompletionIn: .main) { [weak self] result in
                switch result {
                case .success:
                    self?.handleSelectionChange(to: chainModel)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
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
            logger.debug("Did receive balance for accountId: \(accountId.toHex()))")

            switch result {
            case let .success(balance):
                presenter?.didReceiveAccountBalance(balance)
            case let .failure(error):
                presenter?.didReceiveError(error)
            }
        }
    }
}

extension CrowdloanListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceivePriceData(price)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CrowdloanListInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        guard
            let chain = crowdloanState.settings.value,
            chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(blockNumber):
            presenter?.didReceiveBlockNumber(blockNumber)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CrowdloanListInteractor: EventVisitorProtocol {
    func processNetworkEnableChanged(event: NetworkEnabledChanged) {
        guard
            let chain = crowdloanState.settings.value,
            chain.chainId == event.chainId
        else {
            return
        }

        setupState { [weak self] chain in
            guard let chain else { return }

            self?.refresh(with: chain)
        }
    }
}
