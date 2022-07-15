import UIKit

final class AssetsSearchViewController: UIViewController {
    typealias RootViewType = AssetsSearchViewLayout

    let presenter: AssetsSearchPresenterProtocol

    init(presenter: AssetsSearchPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetsSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension AssetsSearchViewController: AssetsSearchViewProtocol {}
