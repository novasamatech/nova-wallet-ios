import UIKit
import SoraFoundation
import SubstrateSdk

final class DAppListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol

    init(presenter: DAppListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
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
        setupHandlers()

        applySubIdViewModel()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.headerView.accountButton.addTarget(
            self,
            action: #selector(actionSelectAccount),
            for: .touchUpInside
        )

        rootView.subIdControlView.addTarget(self, action: #selector(actionSelectSubid), for: .touchUpInside)
    }

    private func setupLocalization() {
        rootView.headerView.titleLabel.text = R.string.localizable.tabbarDappsTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.headerView.decorationTitleLabel.text = R.string.localizable.dappDecorationTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.headerView.decorationSubtitleLabel.text = R.string.localizable.dappsDecorationSubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.listHeaderTitleLabel.text = R.string.localizable.dappsListHeaderTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func applySubIdViewModel() {
        rootView.subIdControlView.controlContentView.iconImageView.image = R.image.iconSubid()
        rootView.subIdControlView.controlContentView.titleLabel.text = "Sub.ID"
        rootView.subIdControlView.controlContentView.subtitleLabel.text =
            "One place to see all your Substrate addresses and balances"
    }

    @objc func actionSelectAccount() {
        presenter.activateAccount()
    }

    @objc func actionSelectSubid() {
        presenter.activateSubId()
    }
}

extension DAppListViewController: DAppListViewProtocol {
    func didReceiveAccount(icon: DrawableIcon) {
        let iconSize = CGSize(
            width: UIConstants.navigationAccountIconSize,
            height: UIConstants.navigationAccountIconSize
        )
        let image = icon.imageWithFillColor(.clear, size: iconSize, contentScale: UIScreen.main.scale)
        rootView.headerView.accountButton.imageWithTitleView?.iconImage = image
        rootView.headerView.accountButton.invalidateLayout()
    }
}

extension DAppListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension DAppListViewController: HiddableBarWhenPushed {}
