import UIKit

final class AHMInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = AHMInfoViewLayout

    let presenter: AHMInfoPresenterProtocol
    let bannersViewProvider: BannersViewProviderProtocol

    init(
        presenter: AHMInfoPresenterProtocol,
        bannersViewProvider: BannersViewProviderProtocol
    ) {
        self.presenter = presenter
        self.bannersViewProvider = bannersViewProvider
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AHMInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBanner()
        setupHandlers()
        presenter.setup()
    }
}

// MARK: - Private

private extension AHMInfoViewController {
    func setupBanner() {
        bannersViewProvider.setupBanners(
            on: self,
            view: rootView.bannerContainer
        )

        let bannerHeight = bannersViewProvider.getMaxBannerHeight()
        rootView.updateBannerHeight(bannerHeight)
    }

    func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionGotIt),
            for: .touchUpInside
        )
    }

    @objc func actionGotIt() {
        presenter.actionGotIt()
    }
}

// MARK: - AHMInfoViewProtocol

extension AHMInfoViewController: AHMInfoViewProtocol {
    func didReceive(viewModel: AHMInfoViewModel) {
        rootView.bind(viewModel)
    }
}
