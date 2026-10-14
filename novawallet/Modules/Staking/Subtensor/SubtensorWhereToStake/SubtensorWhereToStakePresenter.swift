import Foundation
import Foundation_iOS

final class SubtensorWhereToStakePresenter {
    weak var view: SubtensorWhereToStakeViewProtocol?
    let interactor: SubtensorWhereInteractorInputProtocol
    let wireframe: SubtensorWhereToStakeWireframeProtocol
    let viewModelFactory: SubtensorWhereToStakeViewModelFactory
    private(set) var page = 0

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
        selectPage(page)
    }

    func selectPage(_ page: Int) {
        self.page = min(max(page, 0), max(interactor.orders.count - 1, 0))
        view?.didReceive(page: self.page, hasPrevious: self.page > 0, hasNext: self.page < interactor.orders.count - 1)
    }

    func movePage(by offset: Int) { selectPage(page + offset) }

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
