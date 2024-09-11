import UIKit
import SoraFoundation

final class ReferendumVoteSetupViewController: BaseReferendumVoteSetupViewController {
    let presenter: ReferendumVoteSetupPresenterProtocol

    init(
        presenter: ReferendumVoteSetupPresenterProtocol,
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
        rootView.setupVoteButtonsLayout()
    }

    override func setupHandlers() {
        super.setupHandlers()

        rootView.nayButton.addTarget(
            self,
            action: #selector(actionVoteNay),
            for: .touchUpInside
        )

        rootView.ayeButton.addTarget(
            self,
            action: #selector(actionVoteAye),
            for: .touchUpInside
        )

        rootView.abstainButton.addTarget(
            self,
            action: #selector(actionVoteAbstain),
            for: .touchUpInside
        )
    }

    @objc private func actionVoteNay() {
        presenter.proceedNay()
    }

    @objc private func actionVoteAye() {
        presenter.proceedAye()
    }

    @objc private func actionVoteAbstain() {
        presenter.proceedAbstain()
    }
}

// MARK: ReferendumVoteSetupViewProtocol

extension ReferendumVoteSetupViewController: ReferendumVoteSetupViewProtocol {
    func didReceive(abstainAvailable: Bool) {
        abstainAvailable
            ? rootView.showAbstain()
            : rootView.hideAbstain()
    }
}
