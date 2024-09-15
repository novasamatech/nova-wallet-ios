import UIKit
import SoraFoundation

final class TinderGovSetupViewController: BaseReferendumVoteSetupViewController {
    typealias RootViewType = TinderGovSetupViewLayout

    let presenter: TinderGovSetupPresenterProtocol

    var rootView: RootViewType? {
        super.rootView as? RootViewType
    }

    init(
        presenter: TinderGovSetupPresenterProtocol,
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
        view = TinderGovSetupViewLayout()
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

        rootView?.detailsLabel.text = R.string.localizable.govVoteSetupDetailsTinderGov(
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

extension TinderGovSetupViewController: TinderGovSetupViewProtocol {}
