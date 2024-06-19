import UIKit

final class NetworkManageNodeViewController: UIViewController {
    typealias RootViewType = NetworkManageNodeViewLayout

    let presenter: NetworkManageNodePresenterProtocol

    init(presenter: NetworkManageNodePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NetworkManageNodeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NetworkManageNodeViewController: NetworkManageNodeViewProtocol {}