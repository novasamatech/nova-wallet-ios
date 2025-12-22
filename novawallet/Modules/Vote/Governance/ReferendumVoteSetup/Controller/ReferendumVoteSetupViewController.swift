import UIKit
import Foundation_iOS

final class ReferendumVoteSetupViewController: BaseReferendumVoteSetupViewController {
    typealias RootViewType = ReferendumVoteSetupViewLayout

    var rootView: RootViewType? {
        super.rootView as? RootViewType
    }

    let presenter: ReferendumVoteSetupPresenterProtocol

    private var referendumNumber: String?

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

    override func loadView() {
        view = ReferendumVoteSetupViewLayout()
    }

    override func setupHandlers() {
        super.setupHandlers()

        rootView?.nayButton.addTarget(
            self,
            action: #selector(actionVoteNay),
            for: .touchUpInside
        )

        rootView?.ayeButton.addTarget(
            self,
            action: #selector(actionVoteAye),
            for: .touchUpInside
        )

        rootView?.abstainButton.addTarget(
            self,
            action: #selector(actionVoteAbstain),
            for: .touchUpInside
        )
    }

    override func setupLocalization() {
        applyReferendumNumber()

        super.setupLocalization()
    }
}

// MARK: ReferendumVoteSetupViewProtocol

extension ReferendumVoteSetupViewController: ReferendumVoteSetupViewProtocol {
    func didReceive(abstainAvailable: Bool) {
        abstainAvailable
            ? rootView?.showAbstain()
            : rootView?.hideAbstain()
    }

    func didReceive(referendumNumber: String) {
        self.referendumNumber = referendumNumber

        applyReferendumNumber()
    }
}

// MARK: Private

private extension ReferendumVoteSetupViewController {
    func applyReferendumNumber() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(preferredLanguages: languages).localizable.govVoteSetupTitleFormat(
            referendumNumber ?? ""
        )
    }

    @objc func actionVoteNay() {
        presenter.proceedNay()
    }

    @objc func actionVoteAye() {
        presenter.proceedAye()
    }

    @objc func actionVoteAbstain() {
        presenter.proceedAbstain()
    }
}
