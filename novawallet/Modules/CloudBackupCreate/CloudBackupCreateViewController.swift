import UIKit
import SoraFoundation

final class CloudBackupCreateViewController: UIViewController, ViewHolder {
    typealias RootViewType = CloudBackupCreateViewLayout

    let presenter: CloudBackupCreatePresenterProtocol

    init(
        presenter: CloudBackupCreatePresenterProtocol,
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
        view = CloudBackupCreateViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func setupHandlers() {
        rootView.genericActionView.actionButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )

        rootView.enterPasswordView.delegate = self
        rootView.confirmPasswordView.delegate = self

        rootView.enterPasswordView.addTarget(
            self,
            action: #selector(actionEnterPasswordChanged),
            for: .editingChanged
        )

        rootView.confirmPasswordView.addTarget(
            self,
            action: #selector(actionConfirmPasswordChanged),
            for: .editingChanged
        )
    }

    private func setupLocalization() {
        rootView.titleView.valueTop.text = R.string.localizable.cloudBackupCreateTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.titleView.valueBottom.text = R.string.localizable.cloudBackupCreateDetails(
            preferredLanguages: selectedLocale.rLanguages
        )

        let enterPasswordPlaceholder = NSAttributedString(
            string: R.string.localizable.commonBackupPassword(preferredLanguages: selectedLocale.rLanguages),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.enterPasswordView.textField.attributedPlaceholder = enterPasswordPlaceholder

        let confirmPasswordPlaceholder = NSAttributedString(
            string: R.string.localizable.commonConfirmPassword(preferredLanguages: selectedLocale.rLanguages),
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )

        rootView.confirmPasswordView.textField.attributedPlaceholder = confirmPasswordPlaceholder
    }

    @objc func actionContinue() {
        presenter.activateContinue()
    }

    @objc func actionEnterPasswordChanged() {
        presenter.applyEnterPasswordChange()
    }

    @objc func actionConfirmPasswordChanged() {
        presenter.applyConfirmPasswordChange()
    }
}

extension CloudBackupCreateViewController: PasswordInputViewDelegate {
    func passwordInputViewWillStartEditing(_: PasswordInputView) {}

    func passwordInputViewShouldReturn(_ inputView: PasswordInputView) -> Bool {
        if inputView === rootView.enterPasswordView {
            rootView.enterPasswordView.textField.resignFirstResponder()
            rootView.confirmPasswordView.textField.becomeFirstResponder()
        } else {
            rootView.confirmPasswordView.textField.resignFirstResponder()
        }

        return false
    }
}

extension CloudBackupCreateViewController: CloudBackupCreateViewProtocol {
    func didReceive(passwordViewModel: InputViewModelProtocol) {
        rootView.enterPasswordView.bind(inputViewModel: passwordViewModel)
    }

    func didReceive(confirmViewModel: InputViewModelProtocol) {
        rootView.confirmPasswordView.bind(inputViewModel: confirmViewModel)
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
                preferredLanguages: selectedLocale
            )
        } else {
            actionButton.applyDisabledStyle()
            
            actionButton.imageWithTitleView?.title = R.string.localizable.commonEnterPassword(
                preferredLanguages: selectedLocale
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
