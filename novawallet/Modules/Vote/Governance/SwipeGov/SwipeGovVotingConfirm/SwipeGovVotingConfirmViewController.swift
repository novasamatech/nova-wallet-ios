import UIKit
import Foundation_iOS

final class SwipeGovVotingConfirmViewController: BaseReferendumVoteConfirmViewController {
    typealias RootViewType = SwipeGovVotingConfirmViewLayout

    let presenter: SwipeGovVotingConfirmPresenterProtocol

    private var referendaCount: Int?

    init(
        presenter: SwipeGovVotingConfirmPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(
            presenter: presenter,
            localizationManager: localizationManager
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovVotingConfirmViewLayout()
    }

    override func setupLocalization() {
        super.setupLocalization()

        applyReferendaCount()
    }

    private func applyReferendaCount() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.swipeGovConfirmTitle(
            referendaCount ?? 0,
            preferredLanguages: languages
        )
    }
}

extension SwipeGovVotingConfirmViewController: SwipeGovVotingConfirmViewProtocol {
    func didReceive(referendaCount: Int) {
        self.referendaCount = referendaCount

        applyReferendaCount()
    }
}
