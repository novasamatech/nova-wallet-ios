import Foundation
import SubstrateSdk
import SoraFoundation

final class DAppListPresenter {
    weak var view: DAppListViewProtocol?
    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    var selectedLocale: Locale { localizationManager.selectedLocale }

    private var accountId: AccountId?

    private lazy var iconGenerator = NovaIconGenerator()

    init(
        interactor: DAppListInteractorInputProtocol,
        wireframe: DAppListWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func provideAccountIcon() {
        guard let accountId = accountId else {
            return
        }

        do {
            let icon = try iconGenerator.generateFromAccountId(accountId)
            view?.didReceiveAccount(icon: icon)
        } catch {
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

extension DAppListPresenter: DAppListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateAccount() {
        wireframe.showWalletSelection(from: view)
    }

    func activateSearch() {
        wireframe.showSearch(from: view, delegate: self)
    }
}

extension DAppListPresenter: DAppListInteractorOutputProtocol {
    func didReceive(accountIdResult: Result<AccountId, Error>) {
        switch accountIdResult {
        case let .success(accountId):
            self.accountId = accountId
            provideAccountIcon()
        case let .failure(error):
            accountId = nil
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

extension DAppListPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult) {
        wireframe.showBrowser(from: view, for: result)
    }
}
