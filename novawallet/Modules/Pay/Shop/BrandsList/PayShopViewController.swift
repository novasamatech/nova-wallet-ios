import UIKit

final class PayShopViewController: UIViewController, ViewHolder {
    typealias RootViewType = PayShopViewLayout

    let presenter: PayShopPresenterProtocol

    init(presenter: PayShopPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PayShopViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension PayShopViewController: PayShopViewProtocol {
    func didReceive(availabilityViewModel _: PayShopAvailabilityViewModel) {}

    func didReload(viewModels _: [PayShopBrandViewModel]) {}

    func didLoad(viewModels _: [PayShopBrandViewModel]) {}
}
