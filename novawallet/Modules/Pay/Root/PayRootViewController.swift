import UIKit

final class PayRootViewController: UIViewController {
    typealias RootViewType = PayRootViewLayout

    let presenter: PayRootPresenterProtocol

    init(presenter: PayRootPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PayRootViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension PayRootViewController: PayRootViewProtocol {}
