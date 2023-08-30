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
        hintsViewModelFactory: NominationPoolsBondMoreHintsFactoryProtocol,
        logger: LoggerProtocol

    ) {
        super.init(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            hintsViewModelFactory: hintsViewModelFactory,
            logger: logger
        )
    }

    override func updateView() {}

    override func provideHints() {
        hintsViewModelFactory.createHints(
            rewards: claimableRewards,
            locale: selectedLocale
        )
    }

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
