import SoraFoundation

protocol DAppAddFavoriteViewProtocol: ControllerBackedProtocol {
    func didReceive(iconViewModel: ImageViewModelProtocol)
    func didReceive(titleViewModel: InputViewModelProtocol)
    func didReceive(addressViewModel: InputViewModelProtocol)
}

protocol DAppAddFavoritePresenterProtocol: AnyObject {
    func setup()
    func save()
}

protocol DAppAddFavoriteInteractorInputProtocol: AnyObject {
    func setup()
    func save(favorite: DAppFavorite)
}

protocol DAppAddFavoriteInteractorOutputProtocol: AnyObject {
    func didReceive(proposedModel: DAppFavorite)
    func didCompleteSaveWithResult(_ result: Result<Void, Error>)
}

protocol DAppAddFavoriteWireframeProtocol: AlertPresentable, ErrorPresentable {
    func complete(view: DAppAddFavoriteViewProtocol?, locale: Locale)
}
