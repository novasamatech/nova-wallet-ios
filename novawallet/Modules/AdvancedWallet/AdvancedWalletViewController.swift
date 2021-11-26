import UIKit

final class AdvancedWalletViewController: UIViewController {
    typealias RootViewType = AdvancedWalletViewLayout

    let presenter: AdvancedWalletPresenterProtocol

    init(presenter: AdvancedWalletPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AdvancedWalletViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AdvancedWalletViewController: AdvancedWalletViewProtocol {}
