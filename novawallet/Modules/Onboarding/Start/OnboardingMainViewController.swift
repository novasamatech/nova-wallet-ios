import UIKit
import Foundation_iOS
import UIKit_iOS

final class OnboardingMainViewController: UIViewController, ViewHolder {
    typealias RootViewType = OnboardingMainViewLayout

    let presenter: OnboardingMainPresenterProtocol

    init(
        presenter: OnboardingMainPresenterProtocol,
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
        view = OnboardingMainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        updateActionButtons(enabled: false)

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.viewWillAppear()
    }
}

// MARK: - Private

private extension OnboardingMainViewController {
    func setupLocalization() {
        let languages = selectedLocale.rLanguages
        let strings = R.string(preferredLanguages: languages).localizable

        rootView.createButton.imageWithTitleView?.title = strings.onboardingCreateWallet()
        rootView.importButton.imageWithTitleView?.title = strings.onboardingRestoreWallet()
    }

    func setupHandlers() {
        rootView.createButton.addTarget(self, action: #selector(actionSignup), for: .touchUpInside)
        rootView.importButton.addTarget(self, action: #selector(actionRestoreAccess), for: .touchUpInside)

        rootView.consentView.onCheckboxToggle = { [weak self] in
            self?.presenter.toggleConsent()
        }

        rootView.consentView.onLinkTap = { [weak self] type in
            self?.presenter.activateLegalDocument(type)
        }
    }

    /// `applyState(title:enabled:)` and `set(enabled:)` are not used: both hardcode the primary
    /// enabled style, while `importButton` uses the secondary one. Titles never change here, only
    /// the enabled state does.
    func updateActionButtons(enabled: Bool) {
        if enabled {
            rootView.createButton.applyDefaultStyle()
            rootView.importButton.applySecondaryDefaultStyle()
        } else {
            rootView.createButton.applyDisabledStyle()
            rootView.importButton.applyDisabledStyle()
        }

        rootView.createButton.isUserInteractionEnabled = enabled
        rootView.importButton.isUserInteractionEnabled = enabled

        rootView.createButton.invalidateLayout()
        rootView.importButton.invalidateLayout()
    }

    @objc func actionSignup() {
        presenter.activateSignup()
    }

    @objc func actionRestoreAccess() {
        presenter.activateAccountRestore()
    }
}

// MARK: - OnboardingMainViewProtocol

extension OnboardingMainViewController: OnboardingMainViewProtocol {
    func didReceive(viewModel: OnboardingMainViewModel) {
        rootView.consentView.bind(agreement: viewModel.agreement)

        didReceiveConsent(accepted: viewModel.consentAccepted)
    }

    func didReceiveConsent(accepted: Bool) {
        rootView.consentView.isChecked = accepted

        updateActionButtons(enabled: accepted)
    }
}

// MARK: - Localizable

extension OnboardingMainViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()

        presenter.updateLocalization()
    }
}
