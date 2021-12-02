import UIKit
import SoraUI
import SoraFoundation

final class AccountExportPasswordViewController: UIViewController, ImportantViewProtocol, ViewHolder {
    typealias RootViewType = AccountExportPasswordViewLayout

    let presenter: AccountExportPasswordPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    private var passwordInputViewModel: InputViewModelProtocol?
    private var passwordConfirmViewModel: InputViewModelProtocol?

    var inputCompleted: Bool {
        let passwordCompleted = passwordInputViewModel?.inputHandler.completed ?? false
        let confirmationCompleted = passwordConfirmViewModel?.inputHandler.completed ?? false

        return passwordCompleted && confirmationCompleted
    }

    init(
        presenter: AccountExportPasswordPresenterProtocol,
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
        view = AccountExportPasswordViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTextFields()
        setupButtonHandlers()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.exportPasswordTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.subtitleLabel.text = R.string.localizable.accountExportJsonHint(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.setPasswordView.title = R.string.localizable
            .commonSetPassword(preferredLanguages: selectedLocale.rLanguages)

        rootView.confirmPasswordView.title = R.string.localizable
            .commonConfirmPassword(preferredLanguages: selectedLocale.rLanguages)

        updateNextButton()
    }

    private func setupTextFields() {
        rootView.setPasswordView.textField.isSecureTextEntry = true
        rootView.setPasswordView.textField.returnKeyType = .done
        rootView.setPasswordView.delegate = self
        rootView.setPasswordView.addTarget(
            self,
            action: #selector(actionPasswordInputChange),
            for: .editingChanged
        )

        rootView.confirmPasswordView.textField.isSecureTextEntry = true
        rootView.confirmPasswordView.textField.returnKeyType = .done
        rootView.confirmPasswordView.delegate = self
        rootView.confirmPasswordView.addTarget(
            self,
            action: #selector(actionConfirmationInputChange),
            for: .editingChanged
        )
    }

    private func setupButtonHandlers() {
        rootView.setPasswordEyeButton.addTarget(
            self,
            action: #selector(actionPasswordInputEyeToggle),
            for: .touchUpInside
        )

        rootView.confirmPasswordEyeButton.addTarget(
            self,
            action: #selector(actionPasswordConfirmEyeToggle),
            for: .touchUpInside
        )

        rootView.proceedButton.addTarget(self, action: #selector(actionNext), for: .touchUpInside)
    }

    private func updateNextButton() {
        let enabled: Bool
        let title: String

        if let viewModel = passwordInputViewModel, !viewModel.inputHandler.completed {
            enabled = false
            title = R.string.localizable.exportPasswordProceedSetTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else if let viewModel = passwordConfirmViewModel, !viewModel.inputHandler.completed {
            enabled = false
            title = R.string.localizable.exportPasswordProceedConfirmTitle(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            enabled = true
            title = R.string.localizable.commonContinue(preferredLanguages: selectedLocale.rLanguages)
        }

        rootView.proceedButton.imageWithTitleView?.title = title

        if enabled {
            rootView.proceedButton.applyEnabledStyle()
        } else {
            rootView.proceedButton.applyDisabledStyle()
        }

        rootView.proceedButton.isUserInteractionEnabled = enabled
    }

    private func toggleSecurity(_ textField: UITextField, eyeButton: RoundedButton) {
        let isSecure = !textField.isSecureTextEntry

        if isSecure {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconEye()
        } else {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconNoEye()
        }

        textField.isSecureTextEntry = isSecure
    }

    @objc private func actionPasswordInputChange() {
        if passwordInputViewModel?.inputHandler.value != rootView.setPasswordView.text {
            rootView.setPasswordView.text = passwordInputViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc private func actionConfirmationInputChange() {
        if passwordConfirmViewModel?.inputHandler.value != rootView.confirmPasswordView.text {
            rootView.confirmPasswordView.text = passwordConfirmViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @objc private func actionPasswordInputEyeToggle() {
        toggleSecurity(rootView.setPasswordView.textField, eyeButton: rootView.setPasswordEyeButton)
    }

    @objc private func actionPasswordConfirmEyeToggle() {
        toggleSecurity(
            rootView.confirmPasswordView.textField,
            eyeButton: rootView.confirmPasswordEyeButton
        )
    }

    @objc private func actionNext() {
        presenter.proceed()
    }
}

extension AccountExportPasswordViewController: AccountExportPasswordViewProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        passwordInputViewModel = viewModel
        updateNextButton()
    }

    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) {
        passwordConfirmViewModel = viewModel
        updateNextButton()
    }
}

extension AccountExportPasswordViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        if
            textField === rootView.setPasswordView,
            passwordConfirmViewModel?.inputHandler.value.isEmpty == true {
            rootView.confirmPasswordView.becomeFirstResponder()
        } else if textField === rootView.confirmPasswordView, inputCompleted {
            textField.resignFirstResponder()

            presenter.proceed()
        } else {
            textField.resignFirstResponder()
        }

        return false
    }

    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === rootView.setPasswordView {
            viewModel = passwordInputViewModel
        } else {
            viewModel = passwordConfirmViewModel
        }

        guard let currentViewModel = viewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountExportPasswordViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if rootView.setPasswordView.isFirstResponder {
                targetView = rootView.setPasswordBackroundView
            } else if rootView.confirmPasswordView.isFirstResponder {
                targetView = rootView.confirmPasswordBackroundView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

extension AccountExportPasswordViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
