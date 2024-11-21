import UIKit

final class SwapExecutionViewController: UIViewController {
    typealias RootViewType = SwapExecutionViewLayout

    let presenter: SwapExecutionPresenterProtocol

    init(presenter: SwapExecutionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapExecutionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SwapExecutionViewController: SwapExecutionViewProtocol {}