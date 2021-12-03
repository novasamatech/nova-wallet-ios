import UIKit

final class DAppListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol

    init(presenter: DAppListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        rootView.headerView.titleLabel.text = R.string.localizable
            .tabbarCrowdloanTitle_v190(preferredLanguages: languages)
    }
}

extension DAppListViewController: DAppListViewProtocol {}
