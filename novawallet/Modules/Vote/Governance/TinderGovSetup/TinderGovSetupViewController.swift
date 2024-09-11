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

        rootView.nayButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )
    }

    @objc private func actionContinue() {
        // TODO: Implement
    }
}

extension TinderGovSetupViewController: TinderGovSetupViewProtocol {}
