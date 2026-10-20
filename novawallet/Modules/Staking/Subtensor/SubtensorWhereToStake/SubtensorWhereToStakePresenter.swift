import Foundation
import Foundation_iOS
import NovaAnalytics

final class SubtensorWhereToStakePresenter {
    weak var view: SubtensorWhereToStakeViewProtocol?
    let wireframe: SubtensorWhereToStakeWireframeProtocol
    let viewModelFactory: SubtensorWhereToStakeViewModelFactory

    private let abandonTracker = AnalyticsAbandonTracker {
        AnalyticsEvent.subtensorStakingAbandoned(stage: .whereToStake, target: nil)
    }

    init(
        wireframe: SubtensorWhereToStakeWireframeProtocol,
        viewModelFactory: SubtensorWhereToStakeViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

extension SubtensorWhereToStakePresenter: SubtensorWhereToStakePresenterProtocol {
    func setup() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
        view?.didReceive(
            cards: SubtensorQuickPickOrder.allCases.map { viewModelFactory.create(order: $0, locale: selectedLocale) },
            title: strings.stakingSubtensorQuickTitle(),
            caption: strings.stakingSubtensorQuickCaption()
        )
    }

    func choose(_ order: SubtensorQuickPickOrder) {
        abandonTracker.markProceeded()
        wireframe.showSetup(from: view, order: order)
    }
}

extension SubtensorWhereToStakePresenter: Localizable {
    func applyLocalization() {
        guard view?.isSetup == true else { return }
        setup()
    }
}
