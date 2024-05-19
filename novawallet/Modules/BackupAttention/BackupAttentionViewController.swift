import UIKit

final class BackupAttentionViewController: UIViewController {
    typealias RootViewType = BackupAttentionViewLayout

    let presenter: BackupAttentionPresenterProtocol

    init(presenter: BackupAttentionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = BackupAttentionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension BackupAttentionViewController: BackupAttentionViewProtocol {}
