import Foundation
import SoraFoundation

final class DAppAddFavoritePresenter {
    weak var view: DAppAddFavoriteViewProtocol?
    let wireframe: DAppAddFavoriteWireframeProtocol
    let interactor: DAppAddFavoriteInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private(set) var titleViewModel: InputViewModelProtocol?
    private(set) var addressViewModel: InputViewModelProtocol?

    private var proposedModel: DAppFavorite?

    init(
        interactor: DAppAddFavoriteInteractorInputProtocol,
        wireframe: DAppAddFavoriteWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let proposedModel = proposedModel else {
            return
        }

        let iconViewModel: ImageViewModelProtocol

        if let icon = proposedModel.icon, let url = URL(string: icon) {
            iconViewModel = RemoteImageViewModel(url: url)
        } else {
            let defaultIcon = R.image.iconDefaultDapp()!
            iconViewModel = StaticImageViewModel(image: defaultIcon)
        }

        view?.didReceive(iconViewModel: iconViewModel)

        let titleInputHandler = InputHandler(
            value: proposedModel.label ?? "",
            predicate: NSPredicate.notEmpty
        )

        let titleViewModel = InputViewModel(inputHandler: titleInputHandler)
        self.titleViewModel = titleViewModel

        view?.didReceive(titleViewModel: titleViewModel)

        let addressInputHandler = InputHandler(
            value: proposedModel.identifier,
            predicate: NSPredicate.urlPredicate
        )

        let addressViewModel = InputViewModel(inputHandler: addressInputHandler)
        self.addressViewModel = addressViewModel

        view?.didReceive(addressViewModel: addressViewModel)
    }
}

extension DAppAddFavoritePresenter: DAppAddFavoritePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func save() {
        guard
            let title = titleViewModel?.inputHandler.value,
            let urlString = addressViewModel?.inputHandler.value else {
            return
        }

        let favorite = DAppFavorite(identifier: urlString, label: title, icon: proposedModel?.icon)
        interactor.save(favorite: favorite)
    }
}

extension DAppAddFavoritePresenter: DAppAddFavoriteInteractorOutputProtocol {
    func didReceive(proposedModel: DAppFavorite) {
        self.proposedModel = proposedModel

        updateView()
    }

    func didCompleteSaveWithResult(_ result: Result<Void, Error>) {
        let locale = localizationManager.selectedLocale

        switch result {
        case .success:
            wireframe.complete(view: view, locale: locale)
        case let .failure(error):
            if !wireframe.present(error: error, from: view, locale: locale) {
                _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
            }
        }
    }
}
