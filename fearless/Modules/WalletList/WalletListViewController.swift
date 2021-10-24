import UIKit

final class WalletListViewController: UIViewController {
    typealias RootViewType = WalletListViewLayout

    let presenter: WalletListPresenterProtocol

    init(presenter: WalletListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension WalletListViewController: WalletListViewProtocol {}