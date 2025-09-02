import UIKit
import Foundation_iOS

final class CloudBackupCreateViewController: UIViewController, ViewHolder {
    typealias RootViewType = CloudBackupCreateViewLayout

    let presenter: CloudBackupCreatePresenterProtocol
    let flow: CloudBackupSetupPasswordFlow

    init(
        presenter: CloudBackupCreatePresenterProtocol,
        flow: CloudBackupSetupPasswordFlow,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.flow = flow

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CloudBackupCreateViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.activateOnAppear()
        preparePasswordView()
    }

    private func setupHandlers() {
        rootView.genericActionView.actionButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )

        rootView.passwordView.delegate = self

        rootView.passwordView.addTarget(
            self,
            action: #selector(actionEnterPasswordChanged),
            for: .editingChanged
        )
    }

    private func setupView() {
        switch flow {
        case .newBackup, .changePassword:
            rootView.setupAddPassword()
        case .confirmPassword:
            rootView.setupConfirmation()
        }
    }

    private func setupLocalization() {
        switch flow {
        case .newBackup:
            rootView.titleView.valueTop.text = R.string.localizable.cloudBackupCreateTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.titleView.valueBottom.text = R.string.localizable.cloudBackupCreateDetails(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .confirmPassword:
            rootView.titleView.valueTop.text = R.string.localizable.cloudBackupPasswordConfirmTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.titleView.valueBottom.text = R.string.localizable.cloudBackupPasswordConfirmDetails(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .changePassword:
            rootView.titleView.valueTop.text = R.string.localizable.cloudBackupUpdatePasswordTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.titleView.valueBottom.text = R.string.localizable.cloudBackupCreateDetails(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        let passwordPlaceholder = NSAttributedString(
            string: R.string.localizable.commonBackupPassword(preferredLanguages: selectedLocale.rLanguages),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.passwordView.textField.attributedPlaceholder = passwordPlaceholder
    }

    func preparePasswordView() {
        guard flow == .confirmPassword else { return }
        rootView.passwordView.textField.becomeFirstResponder()
    }

    @objc func actionContinue() {
        presenter.activateContinue()
    }

    @objc func actionEnterPasswordChanged() {
        presenter.applyEnterPasswordChange()
    }
}

extension CloudBackupCreateViewController: PasswordInputViewDelegate {
    func passwordInputViewWillStartEditing(_: PasswordInputView) {}

    func passwordInputViewShouldReturn(_: PasswordInputView) -> Bool {
        rootView.passwordView.textField.resignFirstResponder()

        return false
    }
}

extension CloudBackupCreateViewController: CloudBackupCreateViewProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol) {
        rootView.passwordView.bind(inputViewModel: passwordViewModel)
    }

    func didRecieve(hints: [HintListView.ViewModel]) {
        rootView.hintView.bind(viewModels: hints)
    }

    func didReceive(canContinue: Bool) {
        let actionButton = rootView.genericActionView.actionButton
        actionButton.isEnabled = canContinue

        if canContinue {
            actionButton.applyEnabledStyle()
            actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            actionButton.applyDisabledStyle()

            actionButton.imageWithTitleView?.title = R.string.localizable.commonEnterPassword(
                preferredLanguages: selectedLocale.rLanguages
            )
        }
    }

    func didStartLoading() {
        rootView.genericActionView.startLoading()
    }

    func didStopLoading() {
        rootView.genericActionView.stopLoading()
    }
}

extension CloudBackupCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
