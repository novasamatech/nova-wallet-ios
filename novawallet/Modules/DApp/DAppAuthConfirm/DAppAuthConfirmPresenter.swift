import Foundation

final class DAppAuthConfirmPresenter {
    weak var view: DAppAuthConfirmViewProtocol?
    let wireframe: DAppAuthConfirmWireframeProtocol

    let request: DAppAuthRequest
    let viewModelFactory: DAppAuthViewModelFactoryProtocol

    weak var delegate: DAppAuthDelegate?

    init(
        wireframe: DAppAuthConfirmWireframeProtocol,
        request: DAppAuthRequest,
        delegate: DAppAuthDelegate,
        viewModelFactory: DAppAuthViewModelFactoryProtocol
    ) {
        self.wireframe = wireframe
        self.request = request
        self.delegate = delegate
        self.viewModelFactory = viewModelFactory
    }

    private func complete(with result: Bool) {
        let response = DAppAuthResponse(approved: result)
        delegate?.didReceiveAuthResponse(response, for: request)
        wireframe.close(from: view)
    }
}

extension DAppAuthConfirmPresenter: DAppAuthConfirmPresenterProtocol {
    func setup() {
        let viewModel = viewModelFactory.createViewModel(from: request)
        view?.didReceive(viewModel: viewModel)
    }

    func allow() {
        complete(with: true)
    }

    func deny() {
        complete(with: false)
    }
}
