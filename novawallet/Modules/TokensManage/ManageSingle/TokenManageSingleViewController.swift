import UIKit

final class TokenManageSingleViewController: UIViewController {
    typealias RootViewType = TokenManageSingleViewLayout

    let presenter: TokenManageSinglePresenterProtocol

    init(presenter: TokenManageSinglePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokenManageSingleViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension TokenManageSingleViewController: TokenManageSingleViewProtocol {
    func didReceiveNetwork(viewModels _: [TokenManageNetworkViewModel]) {}

    func didReceiveTokenManage(viewModel _: TokenManageViewModel) {}
}
