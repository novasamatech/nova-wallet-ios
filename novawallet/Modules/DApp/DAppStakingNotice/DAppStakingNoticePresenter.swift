import Foundation
import Foundation_iOS
import NovaAnalytics

final class DAppStakingNoticePresenter: AnalyticsTracking {
    weak var view: DAppStakingNoticeViewProtocol?
    let wireframe: DAppStakingNoticeWireframeProtocol
    let context: DAppStakingNoticeContext

    init(
        context: DAppStakingNoticeContext,
        wireframe: DAppStakingNoticeWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.context = context
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }
}

// MARK: Private

private extension DAppStakingNoticePresenter {
    var isBittensor: Bool {
        context.kind == .bittensor
    }

    func provideViewModel() {
        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        let message = if isBittensor {
            strings.dappStakingNoticeBittensorMessage()
        } else {
            strings.dappStakingNoticeMessage()
        }

        // the Bittensor notice offers the site at once, the generic one keeps it behind "Advanced"
        let viewModel = DAppStakingNoticeViewModel(message: message, isContinueRevealed: isBittensor)

        view?.didReceive(viewModel: viewModel)
    }

    func trackAction(_ action: DAppStakingPromptAction) {
        trackDAppStakingPromptAction(
            placement: .notice,
            kind: context.kind.analyticsPromptKind,
            action: action,
            host: context.host
        )
    }
}

// MARK: DAppStakingNoticePresenterProtocol

extension DAppStakingNoticePresenter: DAppStakingNoticePresenterProtocol {
    func setup() {
        provideViewModel()

        trackDAppStakingPromptShown(
            placement: .notice,
            kind: context.kind.analyticsPromptKind,
            host: context.host
        )
    }

    func goToStaking() {
        trackAction(.goToStaking)

        if isBittensor {
            wireframe.redirectToBittensorStaking(from: view, source: .dappNotice)
        } else {
            wireframe.redirectToStaking(from: view)
        }
    }

    func continueToSite() {
        trackAction(.continueToSite)

        wireframe.complete(from: view)
    }
}

// MARK: Localizable

extension DAppStakingNoticePresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideViewModel()
        }
    }
}
