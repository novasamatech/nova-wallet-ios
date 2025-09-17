import UIKit
import Operation_iOS

final class DAppAddFavoriteInteractor {
    weak var presenter: DAppAddFavoriteInteractorOutputProtocol?

    let dAppProvider: AnySingleValueProvider<DAppList>
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let operationQueue: OperationQueue
    let browserPage: DAppBrowserPage

    init(
        browserPage: DAppBrowserPage,
        dAppProvider: AnySingleValueProvider<DAppList>,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        operationQueue: OperationQueue
    ) {
        self.browserPage = browserPage
        self.dAppProvider = dAppProvider
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.operationQueue = operationQueue
    }

    private func provideProposedModel() {
        _ = dAppProvider.fetch { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .success(optList):
                    if let list = optList {
                        self?.handleResultAndMatchModel(list)
                    } else {
                        self?.provideProposedModelWithMatchedDApp(nil)
                    }
                case .none, .failure:
                    // ignore cause we still can propose model
                    self?.provideProposedModelWithMatchedDApp(nil)
                }
            }
        }
    }

    private func handleResultAndMatchModel(_ result: DAppList) {
        let dApps: [DApp] = result.dApps.compactMap { dApp in
            let hasMatch = dApp.url.host == browserPage.url.host && dApp.url.scheme == browserPage.url.scheme
            return hasMatch ? dApp : nil
        }

        if dApps.count == 1, let dApp = dApps.first {
            provideProposedModelWithMatchedDApp(dApp)
        } else {
            let path = browserPage.url
                .pathComponents
                .first { $0 != "/" }

            let dApp = dApps.first {
                $0.url
                    .pathComponents
                    .first { $0 != "/" } == path
            }

            provideProposedModelWithMatchedDApp(dApp)
        }
    }

    private func provideProposedModelWithMatchedDApp(_ dApp: DApp?) {
        let proposedModel = DAppFavorite(
            identifier: browserPage.identifier,
            label: dApp?.name ?? browserPage.title,
            icon: dApp?.icon?.absoluteString,
            index: nil
        )

        presenter?.didReceive(proposedModel: proposedModel)
    }

    private func fetchWithUpdatedIndexesWrapper() -> CompoundOperationWrapper<[DAppFavorite]> {
        let fetchAllOperation = dAppsFavoriteRepository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )

        let indexUpdateOperation = ClosureOperation<[DAppFavorite]> {
            let allFavorites = try fetchAllOperation.extractNoCancellableResultData()

            return allFavorites.map { $0.incrementingIndex() }
        }

        indexUpdateOperation.addDependency(fetchAllOperation)

        return CompoundOperationWrapper(
            targetOperation: indexUpdateOperation,
            dependencies: [fetchAllOperation]
        )
    }

    private func saveFavoriteWrapper(for favorite: DAppFavorite) -> CompoundOperationWrapper<Void> {
        let fetchWrapper = fetchWithUpdatedIndexesWrapper()

        let saveOperation = dAppsFavoriteRepository.saveOperation(
            {
                let allFavorites = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                return allFavorites + [favorite.updatingIndex(to: 0)]
            },
            { [] }
        )

        saveOperation.addDependency(fetchWrapper.targetOperation)

        return fetchWrapper.insertingTail(operation: saveOperation)
    }
}

extension DAppAddFavoriteInteractor: DAppAddFavoriteInteractorInputProtocol {
    func setup() {
        provideProposedModel()
    }

    func save(favorite: DAppFavorite) {
        let wrapper = saveFavoriteWrapper(for: favorite)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didCompleteSaveWithResult(result)
        }
    }
}
