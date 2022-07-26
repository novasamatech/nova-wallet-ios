import UIKit
import RobinHood

final class WalletSelectionInteractor {
    weak var presenter: WalletSelectionInteractorOutputProtocol?

    let repositoryObservable: AnyDataProviderRepositoryObservable<ManagedMetaAccountModel>
    let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private(set) var priceSubscription: AnySingleValueProvider<[PriceData]>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        repositoryObservable: AnyDataProviderRepositoryObservable<ManagedMetaAccountModel>,
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    ) {
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
    }

    private func provideWalletList() {
        let options = RepositoryFetchOptions()
        let operation = repository.fetchAllOperation(with: options)

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let items = try operation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    let changes = items.map { DataProviderChange.insert(newItem: $0) }

                    self?.presenter?.didReceive(changes: changes)
                } catch {
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        let prevPrices = availableTokenPrice
        for change in changes {
            switch change {
            case let .insert(chain), let .update(chain):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != chain.chainId }

                availableTokenPrice = chain.assets.reduce(into: availableTokenPrice) { result, asset in
                    guard let priceId = asset.priceId else {
                        return
                    }

                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                    result[chainAssetId] = priceId
                }
            case let .delete(deletedIdentifier):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != deletedIdentifier }
            }
        }

        if prevPrices != availableTokenPrice {
            updatePriceProvider(for: Set(availableTokenPrice.values))
        }
    }

    private func updatePriceProvider(for priceIdSet: Set<AssetModel.PriceId>) {
        priceSubscription = nil

        let priceIds = Array(priceIdSet).sorted()

        guard !priceIds.isEmpty else {
            return
        }

        priceSubscription = priceLocalSubscriptionFactory.getPriceListProvider(for: priceIds)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in
            let finalValue = changes.reduceToLastChange()

            switch finalValue {
            case let .some(prices):
                let chainPrices = zip(priceIds, prices).reduce(
                    into: [ChainAssetId: PriceData]()
                ) { result, item in
                    guard let chainAssetIds = self?.availableTokenPrice.filter({ $0.value == item.0 })
                        .map(\.key) else {
                        return
                    }

                    for chainAssetId in chainAssetIds {
                        result[chainAssetId] = item.1
                    }
                }

                self?.basePresenter?.didReceivePrices(result: .success(chainPrices))
            case .none:
                self?.basePresenter?.didReceivePrices(result: nil)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.basePresenter?.didReceivePrices(result: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        priceSubscription?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension WalletSelectionInteractor: WalletSelectionInteractorInputProtocol {}

extension WalletSelectionInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAllBalances(result: Result<[DataProviderChange<AssetBalance>], Error>) {

    }
}
