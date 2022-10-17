import UIKit

final class ReferendumVoteSetupViewController: UIViewController {
    typealias RootViewType = ReferendumVoteSetupViewLayout

    let presenter: ReferendumVoteSetupPresenterProtocol

    init(presenter: ReferendumVoteSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferendumVoteSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ReferendumVoteSetupViewController: ReferendumVoteSetupViewProtocol {}
