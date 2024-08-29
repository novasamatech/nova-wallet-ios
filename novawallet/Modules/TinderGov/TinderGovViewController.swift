import UIKit

final class TinderGovViewController: UIViewController {
    typealias RootViewType = TinderGovViewLayout

    let presenter: TinderGovPresenterProtocol

    init(presenter: TinderGovPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TinderGovViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension TinderGovViewController: TinderGovViewProtocol {}