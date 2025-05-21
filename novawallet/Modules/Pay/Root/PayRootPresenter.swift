import Foundation

final class PayRootPresenter {
    weak var view: PayRootViewProtocol?

    let interactor: PayRootInteractorInputProtocol

    init(interactor: PayRootInteractorInputProtocol) {
        self.interactor = interactor
    }
}

private extension PayRootPresenter {
    func updatePageProvider() {
        let provider = PayPageProvider()

        view?.didReceive(pageProvider: provider)
    }
}

extension PayRootPresenter: PayRootPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension PayRootPresenter: PayRootInteractorOutputProtocol {
    func didCompleteSetup() {
        updatePageProvider()
    }

    func didChangeWallet() {
        updatePageProvider()
    }
}
