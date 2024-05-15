import UIKit

final class BackupMnemonicCardViewController: UIViewController {
    typealias RootViewType = BackupMnemonicCardViewLayout

    let presenter: BackupMnemonicCardPresenterProtocol

    init(presenter: BackupMnemonicCardPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BackupMnemonicCardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension BackupMnemonicCardViewController: BackupMnemonicCardViewProtocol {}
