import UIKit

final class MythosStkUnstakeConfirmViewController: UIViewController {
    typealias RootViewType = MythosStkUnstakeConfirmViewLayout

    let presenter: MythosStkUnstakeConfirmPresenterProtocol

    init(presenter: MythosStkUnstakeConfirmPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MythosStkUnstakeConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension MythosStkUnstakeConfirmViewController: MythosStkUnstakeConfirmViewProtocol {}
