import UIKit

final class NominationPoolBondMoreViewController: UIViewController {
    typealias RootViewType = NominationPoolBondMoreViewLayout

    let presenter: NominationPoolBondMorePresenterProtocol

    init(presenter: NominationPoolBondMorePresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NominationPoolBondMoreViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NominationPoolBondMoreViewController: NominationPoolBondMoreViewProtocol {}
