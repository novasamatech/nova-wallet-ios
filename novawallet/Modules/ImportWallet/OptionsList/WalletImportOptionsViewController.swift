import UIKit

final class WalletImportOptionsViewController: UIViewController {
    typealias RootViewType = WalletImportOptionsViewLayout

    let presenter: WalletImportOptionsPresenterProtocol

    init(presenter: WalletImportOptionsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletImportOptionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension WalletImportOptionsViewController: WalletImportOptionsViewProtocol {}
