import UIKit

final class GiftClaimViewController: UIViewController {
    typealias RootViewType = GiftClaimViewLayout

    let presenter: GiftClaimPresenterProtocol

    init(presenter: GiftClaimPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GiftClaimViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension GiftClaimViewController: GiftClaimViewProtocol {}