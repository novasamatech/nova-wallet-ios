import UIKit

final class SwipeGovVotingListViewController: UIViewController {
    typealias RootViewType = SwipeGovVotingListViewLayout

    let presenter: SwipeGovVotingListPresenterProtocol

    init(presenter: SwipeGovVotingListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovVotingListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SwipeGovVotingListViewController: SwipeGovVotingListViewProtocol {}