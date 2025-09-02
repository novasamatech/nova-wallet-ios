import UIKit
import Foundation_iOS

final class SwipeGovSetupViewController: BaseReferendumVoteSetupViewController {
    typealias RootViewType = SwipeGovSetupViewLayout

    let presenter: SwipeGovSetupPresenterProtocol

    var rootView: RootViewType? {
        super.rootView as? RootViewType
    }

    init(
        presenter: SwipeGovSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter

        super.init(
            presenter: presenter,
            localizationManager: localizationManager
        )

        self.localizationManager = localizationManager
    }

    override func loadView() {
        view = SwipeGovSetupViewLayout()
    }

    override func setupHandlers() {
        super.setupHandlers()

        rootView?.continueButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )
    }

    override func setupLocalization() {
        super.setupLocalization()

        rootView?.continueButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView?.detailsLabel.text = R.string.localizable.govVoteSetupDetailsSwipeGov(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView?.titleLabel.text = R.string.localizable.govVotingPower(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc private func actionContinue() {
        presenter.proceed()
    }
}

extension SwipeGovSetupViewController: SwipeGovSetupViewProtocol {}
