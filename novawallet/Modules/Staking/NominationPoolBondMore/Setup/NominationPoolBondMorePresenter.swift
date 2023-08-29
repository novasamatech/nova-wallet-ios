import BigInt

final class NominationPoolBondMorePresenter: NominationPoolBondMoreBasePresenter {
    var wireframe: NominationPoolBondMoreWireframeProtocol? {
        baseWireframe as? NominationPoolBondMoreWireframeProtocol
    }

    var interactor: NominationPoolBondMoreInteractorInputProtocol? {
        baseInteractor as? NominationPoolBondMoreInteractorInputProtocol
    }

    init(
        interactor: NominationPoolBondMoreInteractorInputProtocol,
        wireframe: NominationPoolBondMoreWireframeProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol

    ) {
        super.init(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            logger: logger
        )
    }

    override func updateView() {}

    override func provideHints() {}

    override func provideFee() {}

    override func getInputAmountInPlank() -> BigUInt? {
        nil
    }
}

extension NominationPoolBondMorePresenter: NominationPoolBondMorePresenterProtocol {
    func setup() {
        updateView()

        interactor?.setup()
    }
}
