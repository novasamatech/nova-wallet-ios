import UIKit

final class GiftListViewController: UIViewController {
    typealias RootViewType = GiftListViewLayout

    let presenter: GiftListPresenterProtocol

    init(presenter: GiftListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GiftListViewController: GiftListViewProtocol {}
