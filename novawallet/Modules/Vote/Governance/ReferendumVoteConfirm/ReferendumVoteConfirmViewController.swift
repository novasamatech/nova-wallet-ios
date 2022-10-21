import UIKit

final class ReferendumVoteConfirmViewController: UIViewController {
    typealias RootViewType = ReferendumVoteConfirmViewLayout

    let presenter: ReferendumVoteConfirmPresenterProtocol

    init(presenter: ReferendumVoteConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumVoteConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ReferendumVoteConfirmViewController: ReferendumVoteConfirmViewProtocol {}
