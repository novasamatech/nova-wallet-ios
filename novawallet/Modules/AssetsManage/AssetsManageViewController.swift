import UIKit
import SoraFoundation

final class AssetsManageViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetsManageViewLayout

    let presenter: AssetsManagePresenterProtocol

    init(presenter: AssetsManagePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetsManageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func configure() {
        disableApplyButton()
    }

    private func setupHandlers() {
        rootView.switchControl.addTarget(
            self,
            action: #selector(actionHideZeroBalances),
            for: .valueChanged
        )

        rootView.applyButton.addTarget(
            self,
            action: #selector(actionApply),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.assetsManageTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.controlTitleLabel.text = R.string.localizable.assetsManageHideZeroBalances(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.applyButton.imageWithTitleView?.title = R.string.localizable.commonApply(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func disableApplyButton() {
        rootView.applyButton.isUserInteractionEnabled = false
        rootView.applyButton.applyDisabledStyle()
    }

    private func enableApplyButton() {
        rootView.applyButton.isUserInteractionEnabled = true
        rootView.applyButton.applyEnabledStyle()
    }

    @objc func actionHideZeroBalances() {
        presenter.setHideZeroBalances(value: rootView.switchControl.isOn)
    }

    @objc func actionApply() {
        presenter.apply()
    }
}

extension AssetsManageViewController: AssetsManageViewProtocol {
    func didReceive(viewModel: AssetsManageViewModel) {
        if rootView.switchControl.isOn != viewModel.hideZeroBalances {
            rootView.switchControl.isOn = viewModel.hideZeroBalances
        }

        if viewModel.canApply {
            enableApplyButton()
        } else {
            disableApplyButton()
        }
    }
}

extension AssetsManageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            applyLocalization()
        }
    }
}
