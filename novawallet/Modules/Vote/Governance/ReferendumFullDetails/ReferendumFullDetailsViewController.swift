import UIKit

final class ReferendumFullDetailsViewController: UIViewController {
    typealias RootViewType = ReferendumFullDetailsViewLayout

    let presenter: ReferendumFullDetailsPresenterProtocol

    init(presenter: ReferendumFullDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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

        presenter.setup()
    }
}

extension ReferendumFullDetailsViewController: ReferendumFullDetailsViewProtocol {}
