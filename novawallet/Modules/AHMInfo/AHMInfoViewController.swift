import UIKit
import Foundation_iOS

final class AHMInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = AHMInfoViewLayout

    let presenter: AHMInfoPresenterProtocol
    let bannersViewProvider: BannersViewProviderProtocol

    init(
        presenter: AHMInfoPresenterProtocol,
        bannersViewProvider: BannersViewProviderProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.bannersViewProvider = bannersViewProvider
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
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

        setupNavigation()
        setupBanner()
        setupHandlers()
        presenter.setup()
    }
}

// MARK: - Private

private extension AHMInfoViewController {
    func setupNavigation() {
        let barButtonItem = UIBarButtonItem(
            title: R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonLearnMore(),
            style: .plain,
            target: self,
            action: #selector(actionLearnMore)
        )
        barButtonItem.tintColor = R.color.colorButtonTextAccent()

        navigationController?.navigationBar.topItem?.rightBarButtonItem = barButtonItem
    }

    func setupBanner() {
        bannersViewProvider.setupBanners(
            on: self,
            view: rootView.bannerContainer
        )
        updateBannerHeight()
    }

    func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionGotIt),
            for: .touchUpInside
        )
    }

    func updateBannerHeight() {
        let bannerHeight = bannersViewProvider.getMaxBannerHeight()
        rootView.updateBannerHeight(bannerHeight)
    }

    @objc func actionGotIt() {
        presenter.actionGotIt()
    }

    @objc func actionLearnMore() {
        presenter.actionLearnMore()
    }
}

// MARK: - AHMInfoViewProtocol

extension AHMInfoViewController: AHMInfoViewProtocol {
    func didReceive(viewModel: AHMInfoViewModel) {
        rootView.bind(viewModel)
        updateBannerHeight()
    }
}

// MARK: - Localizable

extension AHMInfoViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupNavigation()
    }
}
