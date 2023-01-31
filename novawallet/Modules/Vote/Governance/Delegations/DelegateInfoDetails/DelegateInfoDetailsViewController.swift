import UIKit

final class DelegateInfoDetailsViewController: UIViewController {
    typealias RootViewType = DelegateInfoDetailsViewLayout

    let presenter: DelegateInfoDetailsPresenterProtocol

    init(presenter: DelegateInfoDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DelegateInfoDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension DelegateInfoDetailsViewController: DelegateInfoDetailsViewProtocol {}