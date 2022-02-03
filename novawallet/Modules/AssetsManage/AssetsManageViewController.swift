import UIKit

final class AssetsManageViewController: UIViewController {
    typealias RootViewType = AssetsManageViewLayout

    let presenter: AssetsManagePresenterProtocol

    init(presenter: AssetsManagePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetsManageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AssetsManageViewController: AssetsManageViewProtocol {}