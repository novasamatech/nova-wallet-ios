import UIKit

final class NPoolsUnstakeSetupViewController: UIViewController {
    typealias RootViewType = NPoolsUnstakeSetupViewLayout

    let presenter: NPoolsUnstakeSetupPresenterProtocol

    init(presenter: NPoolsUnstakeSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NPoolsUnstakeSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NPoolsUnstakeSetupViewController: NPoolsUnstakeSetupViewProtocol {}
