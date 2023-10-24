import UIKit

final class SwapConfirmViewController: UIViewController {
    typealias RootViewType = SwapConfirmViewLayout

    let presenter: SwapConfirmPresenterProtocol

    init(presenter: SwapConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SwapConfirmViewController: SwapConfirmViewProtocol {}
