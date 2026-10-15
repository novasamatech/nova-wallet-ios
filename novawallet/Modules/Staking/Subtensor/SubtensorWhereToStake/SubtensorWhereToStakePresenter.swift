import Foundation
import Foundation_iOS

final class SubtensorWhereToStakePresenter {
    weak var view: SubtensorWhereToStakeViewProtocol?
    let interactor: SubtensorWhereInteractorInputProtocol
    let wireframe: SubtensorWhereToStakeWireframeProtocol
    let viewModelFactory: SubtensorWhereToStakeViewModelFactory

    init(
        interactor: SubtensorWhereInteractorInputProtocol,
        wireframe: SubtensorWhereToStakeWireframeProtocol,
        viewModelFactory: SubtensorWhereToStakeViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

extension SubtensorWhereToStakePresenter: SubtensorWhereToStakePresenterProtocol {
    func setup() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        view?.didReceive(
            cards: interactor.orders.map { viewModelFactory.create(order: $0, locale: selectedLocale) },
            title: strings.stakingSubtensorQuickTitle(),
            caption: strings.stakingSubtensorQuickCaption()
        )
    }

    func choose(_ order: SubtensorQuickPickOrder) {
        guard interactor.orders.contains(order), order.isAvailable else { return }
        wireframe.showSetup(from: view, order: order)
    }
}

extension SubtensorWhereToStakePresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else { return }
        setup()
    }
}
