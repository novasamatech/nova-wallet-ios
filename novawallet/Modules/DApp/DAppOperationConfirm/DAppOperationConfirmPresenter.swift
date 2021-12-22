import Foundation

final class DAppOperationConfirmPresenter {
    weak var view: DAppOperationConfirmViewProtocol?
    let wireframe: DAppOperationConfirmWireframeProtocol
    let interactor: DAppOperationConfirmInteractorInputProtocol
    let logger: LoggerProtocol?

    private(set) weak var delegate: DAppOperationConfirmDelegate?

    init(
        interactor: DAppOperationConfirmInteractorInputProtocol,
        wireframe: DAppOperationConfirmWireframeProtocol,
        delegate: DAppOperationConfirmDelegate,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.delegate = delegate
        self.logger = logger
    }
}

extension DAppOperationConfirmPresenter: DAppOperationConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension DAppOperationConfirmPresenter: DAppOperationConfirmInteractorOutputProtocol {
    func didReceive(modelResult: Result<DAppOperationConfirmModel, Error>) {
        switch modelResult {
        case let .success(model):
            logger?.info("Did receive model: \(model)")
        case let .failure(error):
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceive(feeResult: Result<RuntimeDispatchInfo, Error>) {
        switch feeResult {
        case let .success(fee):
            logger?.info("Did receive fee: \(fee.fee)")
        case let .failure(error):
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceive(priceResult _: Result<PriceData?, Error>) {}

    func didReceive(responseResult _: Result<DAppOperationResponse, Error>) {}
}
