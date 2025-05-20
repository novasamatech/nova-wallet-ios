import UIKit

final class WalletMigrateAcceptViewController: UIViewController {
    typealias RootViewType = WalletMigrateAcceptViewLayout

    let presenter: WalletMigrateAcceptPresenterProtocol

    init(presenter: WalletMigrateAcceptPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletMigrateAcceptViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension WalletMigrateAcceptViewController: WalletMigrateAcceptViewProtocol {}
