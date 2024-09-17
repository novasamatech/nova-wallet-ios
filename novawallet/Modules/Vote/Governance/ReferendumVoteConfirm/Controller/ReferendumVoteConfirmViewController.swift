import UIKit
import SoraFoundation

final class ReferendumVoteConfirmViewController: BaseReferendumVoteConfirmViewController {
    typealias RootViewType = ReferendumVoteConfirmViewLayout

    var rootView: RootViewType? {
        super.rootView as? ReferendumVoteConfirmViewLayout
    }

    let presenter: ReferendumVoteConfirmPresenterProtocol

    private var referendumNumber: String?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumVoteConfirmViewLayout()
    }

    override func setupLocalization() {
        super.setupLocalization()

        applyReferendumNumber()
    }

    private func applyReferendumNumber() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.govVoteSetupTitleFormat(
            referendumNumber ?? "",
            preferredLanguages: languages
        )
    }
}

// MARK: ReferendumVoteConfirmViewProtocol

extension ReferendumVoteConfirmViewController: ReferendumVoteConfirmViewProtocol {
    func didReceive(referendumNumber: String) {
        self.referendumNumber = referendumNumber

        applyReferendumNumber()
    }

    func didReceiveYourVote(viewModel: YourVoteRow.Model) {
        rootView?.yourVoteView.bind(viewModel: viewModel)
    }
}
