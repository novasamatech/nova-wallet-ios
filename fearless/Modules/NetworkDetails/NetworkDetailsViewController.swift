import UIKit

final class NetworkDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkDetailsViewLayout

    let presenter: NetworkDetailsPresenterProtocol

    init(presenter: NetworkDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NetworkDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NetworkDetailsViewController: NetworkDetailsViewProtocol {}
