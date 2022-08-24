import Foundation

final class YourWalletsPresenter {
    weak var view: YourWalletsViewProtocol?
    let wireframe: YourWalletsWireframeProtocol
    let interactor: YourWalletsInteractorInputProtocol
    weak var delegate: YourWalletsDelegate?

    init(
        interactor: YourWalletsInteractorInputProtocol,
        wireframe: YourWalletsWireframeProtocol,
        delegate: YourWalletsDelegate
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.delegate = delegate
    }
}

extension YourWalletsPresenter: YourWalletsPresenterProtocol {
    func setup() {
        delegate?.selectWallet(address: "Test")
    }
}

extension YourWalletsPresenter: YourWalletsInteractorOutputProtocol {}
