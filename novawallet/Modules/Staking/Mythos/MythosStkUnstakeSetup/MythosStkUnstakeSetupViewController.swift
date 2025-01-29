import UIKit

final class MythosStkUnstakeSetupViewController: UIViewController {
    typealias RootViewType = MythosStkUnstakeSetupViewLayout

    let presenter: MythosStkUnstakeSetupPresenterProtocol

    init(presenter: MythosStkUnstakeSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MythosStkUnstakeSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension MythosStkUnstakeSetupViewController: MythosStkUnstakeSetupViewProtocol {}
