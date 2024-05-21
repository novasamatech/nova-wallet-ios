import UIKit

final class ManualBackupKeyListViewController: UIViewController {
    typealias RootViewType = ManualBackupKeyListViewLayout

    let presenter: ManualBackupKeyListPresenterProtocol

    init(presenter: ManualBackupKeyListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ManualBackupKeyListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ManualBackupKeyListViewController: ManualBackupKeyListViewProtocol {}