import UIKit

final class SwipeGovVotingConfirmViewController: UIViewController {
    typealias RootViewType = SwipeGovVotingConfirmViewLayout

    let presenter: SwipeGovVotingConfirmPresenterProtocol

    init(presenter: SwipeGovVotingConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

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