import UIKit

final class WalletSelectionViewController: UIViewController {
    typealias RootViewType = WalletSelectionViewLayout

    let presenter: WalletSelectionPresenterProtocol

    init(presenter: WalletSelectionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletSelectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension WalletSelectionViewController: WalletSelectionViewProtocol {}