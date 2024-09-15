import Foundation
import Operation_iOS

final class SwipeGovVotingListInteractor {
    weak var presenter: SwipeGovVotingListInteractorOutputProtocol?

    let votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol

    private let observableState: ReferendumsObservableState

    private let chain: ChainModel
    private let metaAccount: MetaAccountModel

    private let repository: AnyDataProviderRepository<VotingBasketItemLocal>

    private let selectedGovOption: GovernanceSelectedOption

    private var basketItemsProvider: StreamableProvider<VotingBasketItemLocal>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    private var currentVotingItems: [VotingBasketItemLocal] = []

    private let operationQueue: OperationQueue

    init(
        observableState: ReferendumsObservableState,
        chain: ChainModel,
        metaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<VotingBasketItemLocal>,
        selectedGovOption: GovernanceSelectedOption,
        votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.observableState = observableState
        self.chain = chain
        self.metaAccount = metaAccount
        self.repository = repository
        self.selectedGovOption = selectedGovOption
        self.votingBasketSubscriptionFactory = votingBasketSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.operationQueue = operationQueue
    }
}

// MARK: SwipeGovVotingListInteractorInputProtocol

extension SwipeGovVotingListInteractor: SwipeGovVotingListInteractorInputProtocol {
    func setup() {
        subscribeToLocalStorages()

        observableState.addObserver(
            with: self,
            queue: .main
        ) { [weak self] _, new in
            self?.onReceiveObservableState(new.value)
        }
    }

    func removeItem(with identifier: String) {
        deleteItem(with: identifier)
    }
}

// MARK: VotingBasketLocalStorageSubscriber

extension SwipeGovVotingListInteractor: VotingBasketLocalStorageSubscriber, VotingBasketSubscriptionHandler {
    func handleVotingBasketItems(result: Result<[DataProviderChange<VotingBasketItemLocal>], any Error>) {
        switch result {
        case let .success(votingsChanges):
            currentVotingItems = currentVotingItems.applying(changes: votingsChanges)
            presenter?.didReceive(votingsChanges)
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: WalletLocalStorageSubscriber

extension SwipeGovVotingListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, any Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceive(balance)
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: GovMetadataLocalStorageSubscriber

extension SwipeGovVotingListInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
    func handleGovernanceMetadataPreview(
        result: Result<[DataProviderChange<ReferendumMetadataLocal>], any Error>,
        option: GovernanceSelectedOption
    ) {
        guard selectedGovOption == option else {
            return
        }

        switch result {
        case let .success(changes):
            presenter?.didReceive(changes)
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}

// MARK: Private

private extension SwipeGovVotingListInteractor {
    func deleteItem(with identifier: String) {
        let deleteOperation = repository.saveOperation(
            { [] },
            { [identifier] }
        )

        execute(
            operation: deleteOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { _ in }
    }

    func subscribeToLocalStorages() {
        guard
            let accountId = metaAccount.fetch(for: chain.accountRequest())?.accountId,
            let assetId = chain.utilityAsset()?.assetId
        else {
            return
        }

        subscribeAssetBalance(
            for: accountId,
            chainId: chain.chainId,
            assetId: assetId
        )

        subscribeVotingBasketItems(
            for: chain.chainId,
            metaId: metaAccount.metaId
        )

        metadataProvider = subscribeGovernanceMetadata(for: selectedGovOption)
    }

    func subscribeAssetBalance(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainId,
            assetId: assetId
        )
    }

    func subscribeVotingBasketItems(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) {
        basketItemsProvider = subscribeToVotingBasketItemProvider(
            for: chainId,
            metaId: metaId
        )
    }

    func onReceiveObservableState(_ state: ReferendumsState) {
        let filteredReferendums = ReferendumFilter.VoteAvailable(
            referendums: state.referendums,
            accountVotes: state.voting?.value?.votes
        ).callAsFunction()

        let unavailableItems = currentVotingItems.filter { item in
            filteredReferendums[item.referendumId] == nil
        }

        guard !unavailableItems.isEmpty else { return }

        unavailableItems.forEach { item in
            deleteItem(with: item.identifier)
        }

        presenter?.didReceiveUnavailableItems()
    }
}
