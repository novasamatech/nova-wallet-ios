import UIKit

final class GovRemoveVotesConfirmViewController: UIViewController {
    typealias RootViewType = GovernanceRemoveVotesConfirmViewLayout

    let presenter: GovernanceRemoveVotesConfirmPresenterProtocol

    init(presenter: GovernanceRemoveVotesConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceRemoveVotesConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GovRemoveVotesConfirmViewController: GovernanceRemoveVotesConfirmViewProtocol {
    func didReceiveWallet(viewModel _: StackCellViewModel) {}

    func didReceiveAccount(viewModel _: DisplayAddressViewModel) {}

    func didReceiveFee(viewModel _: BalanceViewModelProtocol?) {}

    func didReceiveTracks(viewModel _: String) {}
}
