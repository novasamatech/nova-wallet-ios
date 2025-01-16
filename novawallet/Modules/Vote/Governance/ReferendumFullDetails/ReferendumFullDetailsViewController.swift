import UIKit
import Foundation_iOS

final class ReferendumFullDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferendumFullDetailsViewLayout

    let presenter: ReferendumFullDetailsPresenterProtocol

    init(presenter: ReferendumFullDetailsPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumFullDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.govFullDetails(preferredLanguages: selectedLocale.rLanguages)
    }

    @objc private func actionProposer() {
        presenter.presentProposer()
    }

    @objc private func actionBeneficiary() {
        presenter.presentBeneficiary()
    }

    @objc private func actionCallHash() {
        presenter.presentCallHash()
    }
}

extension ReferendumFullDetailsViewController: ReferendumFullDetailsViewProtocol {
    func didReceive(proposer: ReferendumFullDetailsViewModel.Proposer?) {
        rootView.setProposer(viewModel: proposer, locale: selectedLocale)

        rootView.proposerCell?.addTarget(
            self,
            action: #selector(actionProposer),
            for: .touchUpInside
        )
    }

    func didReceive(beneficiary: ReferendumFullDetailsViewModel.Beneficiary?) {
        rootView.setBeneficiary(viewModel: beneficiary, locale: selectedLocale)

        rootView.beneficiaryCell?.addTarget(
            self,
            action: #selector(actionBeneficiary),
            for: .touchUpInside
        )
    }

    func didReceive(params: ReferendumFullDetailsViewModel.Voting?) {
        rootView.setVoting(viewModel: params, locale: selectedLocale)

        rootView.callHashCell?.addTarget(
            self,
            action: #selector(actionCallHash),
            for: .touchUpInside
        )
    }

    func didReceive(json: String?) {
        rootView.setJson(viewModel: json, locale: selectedLocale)
    }

    func didReceiveTooLongJson() {
        rootView.setTooLongJson(for: selectedLocale)
    }
}

extension ReferendumFullDetailsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
