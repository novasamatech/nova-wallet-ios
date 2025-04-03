import UIKit
import Foundation_iOS

final class OnboardingWalletReadyViewController: UIViewController, ViewHolder {
    typealias RootViewType = OnboardingWalletReadyViewLayout

    let presenter: OnboardingWalletReadyPresenterProtocol

    init(presenter: OnboardingWalletReadyPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = OnboardingWalletReadyViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.walletReadyTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.subtitleLabel.text = R.string.localizable.walletReadySubtitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.cloudBackupButton.imageWithTitleView?.title = R.string.localizable.commonContinueWithAppleBackup(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.manualBackupButton.imageWithTitleView?.title = R.string.localizable.commonContinueWithManualBackup(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupHandlers() {
        rootView.cloudBackupButton.addTarget(
            self,
            action: #selector(actionCloudBackup),
            for: .touchUpInside
        )

        rootView.manualBackupButton.addTarget(
            self,
            action: #selector(actionManualBackup),
            for: .touchUpInside
        )
    }

    @objc func actionCloudBackup() {
        presenter.applyCloudBackup()
    }

    @objc func actionManualBackup() {
        presenter.applyManualBackup()
    }
}

extension OnboardingWalletReadyViewController: OnboardingWalletReadyViewProtocol {
    func didReceive(walletName: String) {
        rootView.walletNameInputView.textField.text = walletName
    }

    func didStartBackupLoading() {
        rootView.cloudBackupActionView.startLoading()

        rootView.manualBackupButton.isEnabled = false
        rootView.manualBackupButton.applyDisabledStyle()
    }

    func didStopBackupLoading() {
        rootView.cloudBackupActionView.stopLoading()

        rootView.manualBackupButton.isEnabled = true
        rootView.manualBackupButton.applySecondaryEnabledStyle()
    }
}

extension OnboardingWalletReadyViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
