import UIKit

final class CustomNetworkViewController: UIViewController {
    typealias RootViewType = CustomNetworkViewLayout

    let presenter: CustomNetworkPresenterProtocol

    init(presenter: CustomNetworkPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CustomNetworkViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension CustomNetworkViewController: CustomNetworkViewProtocol {}