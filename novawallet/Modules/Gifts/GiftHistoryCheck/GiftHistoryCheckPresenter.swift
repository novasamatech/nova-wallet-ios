import Foundation
import Foundation_iOS

final class GiftHistoryCheckPresenter {
    weak var view: GiftHistoryCheckViewProtocol?
    let wireframe: GiftHistoryCheckWireframeProtocol
    let interactor: GiftHistoryCheckInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: GiftHistoryCheckInteractorInputProtocol,
        wireframe: GiftHistoryCheckWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

// MARK: - GiftHistoryCheckPresenterProtocol

extension GiftHistoryCheckPresenter: GiftHistoryCheckPresenterProtocol {
    func setup() {
        view?.didReceive(true)
        interactor.setup()
    }
}

// MARK: - GiftHistoryCheckInteractorOutputProtocol

extension GiftHistoryCheckPresenter: GiftHistoryCheckInteractorOutputProtocol {
    func didReceive(_ gifts: [GiftModel]) {
        view?.didReceive(false)

        guard !gifts.isEmpty else {
            wireframe.showOnboarding(from: view)
            return
        }

        wireframe.showHistory(
            from: view,
            gifts: gifts
        )
    }

    func didReceive(_: any Error) {
        view?.didReceive(false)
        wireframe.presentRequestStatus(
            on: view,
            locale: localizationManager.selectedLocale,
            retryAction: { [weak self] in
                self?.interactor.fetchGifts()
            }
        )
    }
}
