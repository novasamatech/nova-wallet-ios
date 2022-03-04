import UIKit

final class NftDetailsViewController: UIViewController {
    typealias RootViewType = NftDetailsViewLayout

    let presenter: NftDetailsPresenterProtocol

    init(presenter: NftDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NftDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension NftDetailsViewController: NftDetailsViewProtocol {}
