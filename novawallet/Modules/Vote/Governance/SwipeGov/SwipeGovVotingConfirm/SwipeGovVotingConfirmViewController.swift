import UIKit

final class SwipeGovVotingConfirmViewController: BaseReferendumVoteConfirmViewController {
    typealias RootViewType = SwipeGovVotingConfirmViewLayout

    let presenter: SwipeGovVotingConfirmPresenterProtocol

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovVotingConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SwipeGovVotingConfirmViewController: SwipeGovVotingConfirmViewProtocol {}
