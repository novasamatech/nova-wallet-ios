import UIKit
import SoraFoundation

final class SwipeGovReferendumDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwipeGovReferendumDetailsViewLayout

    let presenter: SwipeGovReferendumDetailsPresenterProtocol

    init(
        presenter: SwipeGovReferendumDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovReferendumDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension SwipeGovReferendumDetailsViewController: SwipeGovReferendumDetailsViewProtocol {}
