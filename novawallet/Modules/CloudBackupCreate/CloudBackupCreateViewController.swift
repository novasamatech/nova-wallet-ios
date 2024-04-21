import UIKit

final class CloudBackupCreateViewController: UIViewController {
    typealias RootViewType = CloudBackupCreateViewLayout

    let presenter: CloudBackupCreatePresenterProtocol

    init(presenter: CloudBackupCreatePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CloudBackupCreateViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension CloudBackupCreateViewController: CloudBackupCreateViewProtocol {}
