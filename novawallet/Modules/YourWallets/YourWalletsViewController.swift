import UIKit

final class YourWalletsViewController: UIViewController {
    typealias RootViewType = YourWalletsViewLayout

    let presenter: YourWalletsPresenterProtocol

    init(presenter: YourWalletsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = YourWalletsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }

}

extension YourWalletsViewController: YourWalletsViewProtocol {}
