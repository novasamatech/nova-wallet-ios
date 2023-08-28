import Foundation
import SoraFoundation

final class NPoolsUnstakeSetupPresenter: NPoolsUnstakeBasePresenter {
    weak var view: NPoolsUnstakeSetupViewProtocol?

    var wireframe: NPoolsUnstakeSetupWireframeProtocol? {
        baseWireframe as? NPoolsUnstakeSetupWireframeProtocol
    }

    var interactor: NPoolsUnstakeSetupInteractorInputProtocol? {
        baseInteractor as? NPoolsUnstakeSetupInteractorInputProtocol
    }

    init(
        interactor: NPoolsUnstakeSetupInteractorInputProtocol,
        wireframe: NPoolsUnstakeSetupWireframeProtocol,
        chainAsset: ChainAsset,
        hintsViewModelFactory: NPoolsUnstakeHintsFactoryProtocol,
        dataValidatorFactory: NominationPoolDataValidatorFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        super.init(
            baseInteractor: interactor,
            baseWireframe: wireframe,
            chainAsset: chainAsset,
            hintsViewModelFactory: hintsViewModelFactory,
            dataValidatorFactory: dataValidatorFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }
}

extension NPoolsUnstakeSetupPresenter: NPoolsUnstakeSetupPresenterProtocol {
    func setup() {
        updateView()

        interactor?.setup()
    }
}

extension NPoolsUnstakeSetupPresenter: NPoolsUnstakeSetupInteractorOutputProtocol {}
