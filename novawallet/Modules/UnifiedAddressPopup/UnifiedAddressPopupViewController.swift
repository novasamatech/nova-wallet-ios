import UIKit

final class UnifiedAddressPopupViewController: UIViewController {
    typealias RootViewType = UnifiedAddressPopupViewLayout

    let presenter: UnifiedAddressPopupPresenterProtocol

    init(presenter: UnifiedAddressPopupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UnifiedAddressPopupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension UnifiedAddressPopupViewController: UnifiedAddressPopupViewProtocol {}