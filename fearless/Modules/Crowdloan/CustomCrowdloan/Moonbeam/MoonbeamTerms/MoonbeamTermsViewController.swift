import UIKit

final class MoonbeamTermsViewController: UIViewController {
    typealias RootViewType = MoonbeamTermsViewLayout

    let presenter: MoonbeamTermsPresenterProtocol

    init(presenter: MoonbeamTermsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MoonbeamTermsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension MoonbeamTermsViewController: MoonbeamTermsViewProtocol {}
