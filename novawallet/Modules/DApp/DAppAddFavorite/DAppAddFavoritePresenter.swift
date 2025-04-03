import Foundation
import Foundation_iOS

final class DAppAddFavoritePresenter {
    weak var view: DAppAddFavoriteViewProtocol?
    let wireframe: DAppAddFavoriteWireframeProtocol
    let interactor: DAppAddFavoriteInteractorInputProtocol
    let iconViewModelFactory: DAppIconViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private(set) var titleViewModel: InputViewModelProtocol?
    private(set) var addressViewModel: InputViewModelProtocol?

    private var proposedModel: DAppFavorite?

    init(
        interactor: DAppAddFavoriteInteractorInputProtocol,
        wireframe: DAppAddFavoriteWireframeProtocol,
        iconViewModelFactory: DAppIconViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.iconViewModelFactory = iconViewModelFactory
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let proposedModel = proposedModel else {
            return
        }

        let iconViewModel = iconViewModelFactory.createIconViewModel(for: proposedModel)

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

        let favorite = DAppFavorite(
            identifier: urlString,
            label: title,
            icon: proposedModel?.icon,
            index: nil
        )
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
