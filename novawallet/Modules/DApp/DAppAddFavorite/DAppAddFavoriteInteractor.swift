import UIKit
import RobinHood

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
                    // ignore ignore cause we still can propose model
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
            provideProposedModelWithMatchedDApp(nil)
        }
    }

    private func provideProposedModelWithMatchedDApp(_ dApp: DApp?) {
        let proposedModel = DAppFavorite(
            identifier: browserPage.identifier,
            label: dApp?.name ?? browserPage.title,
            icon: dApp?.icon?.absoluteString
        )

        presenter?.didReceive(proposedModel: proposedModel)
    }
}

extension DAppAddFavoriteInteractor: DAppAddFavoriteInteractorInputProtocol {
    func setup() {
        provideProposedModel()
    }

    func save(favorite: DAppFavorite) {
        let saveOperation = dAppsFavoriteRepository.saveOperation({ [favorite] }, { [] })

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()

                    self?.presenter?.didCompleteSaveWithResult(.success(()))
                } catch {
                    self?.presenter?.didCompleteSaveWithResult(.failure(error))
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}
