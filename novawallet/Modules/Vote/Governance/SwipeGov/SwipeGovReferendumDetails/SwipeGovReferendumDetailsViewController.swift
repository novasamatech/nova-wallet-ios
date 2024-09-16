import UIKit

final class SwipeGovReferendumDetailsViewController: UIViewController {
    typealias RootViewType = SwipeGovReferendumDetailsViewLayout

    let presenter: SwipeGovReferendumDetailsPresenterProtocol

    init(presenter: SwipeGovReferendumDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovReferendumDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SwipeGovReferendumDetailsViewController: SwipeGovReferendumDetailsViewProtocol {}