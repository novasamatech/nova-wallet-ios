import UIKit

final class ParaStkRebondViewController: UIViewController {
    typealias RootViewType = ParaStkRebondViewLayout

    let presenter: ParaStkRebondPresenterProtocol

    init(presenter: ParaStkRebondPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ParaStkRebondViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension ParaStkRebondViewController: ParaStkRebondViewProtocol {}
