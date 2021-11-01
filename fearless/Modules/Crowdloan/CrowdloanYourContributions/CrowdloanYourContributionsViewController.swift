import UIKit

final class CrowdloanYourContributionsViewController: UIViewController {
    typealias RootViewType = CrowdloanYourContributionsViewLayout

    let presenter: CrowdloanYourContributionsPresenterProtocol

    init(presenter: CrowdloanYourContributionsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanYourContributionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

extension CrowdloanYourContributionsViewController: CrowdloanYourContributionsViewProtocol {}
