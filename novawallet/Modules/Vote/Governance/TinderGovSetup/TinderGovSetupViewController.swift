import UIKit
import SoraFoundation

final class TinderGovSetupViewController: BaseReferendumVoteSetupViewController {
    let presenter: TinderGovSetupPresenterProtocol

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

    override func setupView() {
        rootView.setupSingleButtonLayout()
    }

    override func setupHandlers() {
        super.setupHandlers()

        rootView.continueButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )
    }

    override func setupLocalization() {
        super.setupLocalization()

        rootView.continueButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc private func actionContinue() {
        presenter.proceed()
    }
}

extension TinderGovSetupViewController: TinderGovSetupViewProtocol {}
