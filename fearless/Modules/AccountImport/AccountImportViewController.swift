import UIKit
import SoraKeystore
import SoraFoundation
import SoraUI

final class AccountImportViewController: UIViewController {
    private enum Constants {
        static let verticalSpacing: CGFloat = 16.0
    }

    var presenter: AccountImportPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var sourceTypeView: BorderedSubtitleActionView!
    @IBOutlet private var usernameView: UIView!
    @IBOutlet private var usernameTextField: AnimatedTextField!
    @IBOutlet private var usernameFooterLabel: UILabel!
    @IBOutlet private var passwordView: TriangularedView!
    @IBOutlet private var passwordTextField: AnimatedTextField!
    @IBOutlet private var textPlaceholderLabel: UILabel!
    @IBOutlet private var textView: UITextView!
    @IBOutlet private var nextButton: TriangularedButton!

    @IBOutlet private var textContainerView: UIView!

    @IBOutlet private var uploadView: DetailsTriangularedView!

    @IBOutlet private var warningView: UIView!
    @IBOutlet private var warningLabel: UILabel!

    @IBOutlet var substrateCryptoTypeView: BorderedSubtitleActionView!
    @IBOutlet var ethereumCryptoTypeView: BorderedSubtitleActionView!

    @IBOutlet var substrateDerivationPathView: TriangularedView!
    @IBOutlet var substrateDerivationPathLabel: UILabel!
    @IBOutlet var substrateDerivationPathField: UITextField!
    @IBOutlet var substrateDerivationPathImageView: UIImageView!

    @IBOutlet var ethereumDerivationPathView: TriangularedView!
    @IBOutlet var ethereumDerivationPathLabel: UILabel!
    @IBOutlet var ethereumDerivationPathField: UITextField!
    @IBOutlet var ethereumDerivationPathImageView: UIImageView!

    @IBOutlet var advancedContainerView: UIView!
    @IBOutlet var advancedControl: ExpandableActionControl!

    private var substrateDerivationPathModel: InputViewModelProtocol?
    private var ethereumDerivationPathModel: InputViewModelProtocol?
    private var usernameViewModel: InputViewModelProtocol?
    private var passwordViewModel: InputViewModelProtocol?
    private var sourceViewModel: InputViewModelProtocol?

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromBottom,
        curve: .easeOut
    )

    var advancedDismissalAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromTop,
        curve: .easeIn
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        updateTextViewPlaceholder()

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

    // MARK: - Setup functions

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }

        stackView.setCustomSpacing(Constants.verticalSpacing, after: sourceTypeView)
        stackView.setCustomSpacing(Constants.verticalSpacing, after: uploadView)

        advancedContainerView.isHidden = !advancedControl.isActivated

        confirgurePlaceholder(for: substrateDerivationPathField)
        confirgurePlaceholder(for: ethereumDerivationPathField)

        textView.tintColor = R.color.colorWhite()

        sourceTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenSourceType),
            for: .valueChanged
        )

        substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOpenCryptoType),
            for: .valueChanged
        )

        ethereumCryptoTypeView.actionControl.showsImageIndicator = false
        ethereumCryptoTypeView.applyDisabledStyle()

        usernameTextField.textField.returnKeyType = .done
        usernameTextField.textField.textContentType = .nickname
        usernameTextField.textField.autocapitalizationType = .none
        usernameTextField.textField.autocorrectionType = .no
        usernameTextField.textField.spellCheckingType = .no

        passwordTextField.textField.returnKeyType = .done
        passwordTextField.textField.textContentType = .password
        passwordTextField.textField.autocapitalizationType = .none
        passwordTextField.textField.autocorrectionType = .no
        passwordTextField.textField.spellCheckingType = .no
        passwordTextField.textField.isSecureTextEntry = true

        usernameTextField.delegate = self
        passwordTextField.delegate = self

        uploadView.addTarget(self, action: #selector(actionUpload), for: .touchUpInside)
    }

    private func confirgurePlaceholder(for textField: UITextField) {
        guard let placeholder = textField.placeholder else { return }

        let color = R.color.colorGray() ?? .gray
        let attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: color]
        )

        textField.attributedPlaceholder = attributedPlaceholder
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable
            .importWalletTitle(preferredLanguages: locale.rLanguages)
        sourceTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale.rLanguages)

        setupUsernamePlaceholder(for: locale)

        usernameFooterLabel.text = R.string.localizable
            .walletUsernameSetupHint(preferredLanguages: locale.rLanguages)

        setupPasswordPlaceholder(for: locale)

        advancedControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)
        advancedControl.invalidateLayout()

        substrateCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonCryptoTypeSubstrate(preferredLanguages: locale.rLanguages)
        substrateCryptoTypeView.actionControl.invalidateLayout()

        ethereumCryptoTypeView.actionControl.contentView.titleLabel.text = R.string.localizable
            .commonCryptoTypeEthereum(preferredLanguages: locale.rLanguages)
        ethereumCryptoTypeView.actionControl.invalidateLayout()

        substrateDerivationPathLabel.text = R.string.localizable
            .commonSecretDerivationPathSubstrate(preferredLanguages: locale.rLanguages)
        ethereumDerivationPathLabel.text = R.string.localizable
            .commonSecretDerivationPathEthereum(preferredLanguages: locale.rLanguages)

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonNext(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()

        uploadView.title = R.string.localizable.importRecoveryJson(preferredLanguages: locale.rLanguages)

        if !uploadView.isHidden {
            updateUploadView()
        }
    }

    private func setupUsernamePlaceholder(for locale: Locale) {
        usernameTextField.title = R.string.localizable
            .walletUsernameSetupChooseTitle(preferredLanguages: locale.rLanguages)
    }

    private func setupPasswordPlaceholder(for locale: Locale) {
        passwordTextField.title = R.string.localizable
            .accountImportPasswordPlaceholder(preferredLanguages: locale.rLanguages)
    }

    // MARK: - Update UI functions

    private func updateNextButton() {
        var isEnabled: Bool = true

        if let viewModel = sourceViewModel, viewModel.inputHandler.required {
            let uploadViewActive = !uploadView.isHidden && !(uploadView.subtitle?.isEmpty ?? false)
            let textViewActive = !textContainerView.isHidden && !textView.text.isEmpty
            isEnabled = isEnabled && (uploadViewActive || textViewActive)
        }

        if let viewModel = usernameViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(usernameTextField.text?.isEmpty ?? true)
        }

        if let viewModel = passwordViewModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(passwordTextField.text?.isEmpty ?? true)
        }

        if let viewModel = substrateDerivationPathModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(substrateDerivationPathField.text?.isEmpty ?? true)
        }

        if let viewModel = ethereumDerivationPathModel, viewModel.inputHandler.required {
            isEnabled = isEnabled && !(ethereumDerivationPathField.text?.isEmpty ?? true)
        }

        nextButton?.set(enabled: isEnabled)
    }

    private func updateTextViewPlaceholder() {
        textPlaceholderLabel.isHidden = !textView.text.isEmpty
    }

    private func updateUploadView() {
        if let viewModel = sourceViewModel, !viewModel.inputHandler.normalizedValue.isEmpty {
            uploadView.subtitleLabel?.textColor = R.color.colorWhite()
            uploadView.subtitle = viewModel.inputHandler.normalizedValue
        } else {
            uploadView.subtitleLabel?.textColor = R.color.colorLightGray()

            let locale = localizationManager?.selectedLocale
            uploadView.subtitle = R.string.localizable.recoverJsonHint(preferredLanguages: locale?.rLanguages)
        }
    }

    private func updateSubstrateDerivationPath(status: FieldStatus) {
        substrateDerivationPathImageView.image = status.icon
    }

    private func updateEthereumDerivationPath(status: FieldStatus) {
        ethereumDerivationPathImageView.image = status.icon
    }

    private func setDerivationPath(viewModel: InputViewModelProtocol, for textField: UITextField) {
        textField.text = viewModel.inputHandler.value

        let attributedPlaceholder = NSAttributedString(
            string: viewModel.placeholder,
            attributes: [.foregroundColor: R.color.colorGray()!]
        )

        textField.attributedPlaceholder = attributedPlaceholder
    }

    private func updateTextField(_ textField: UITextField, model: InputViewModelProtocol?) {
        if model?.inputHandler.value != textField.text {
            textField.text = model?.inputHandler.value
        }
    }

    // MARK: - Actions

    @IBAction private func actionExpand() {
        stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !advancedControl.isActivated

        if advancedControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            substrateDerivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    // FIXME: add to actionTextFieldChanged(_ sender: UITextField)
    @IBAction private func actionNameTextFieldChanged() {
        if usernameViewModel?.inputHandler.value != usernameTextField.text {
            usernameTextField.text = usernameViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @IBAction private func actionPasswordTextFieldChanged() {
        if passwordViewModel?.inputHandler.value != passwordTextField.text {
            passwordTextField.text = passwordViewModel?.inputHandler.value
        }

        updateNextButton()
    }

    @IBAction private func actionTextFieldChanged(_ sender: UITextField) {
        if sender == substrateDerivationPathField {
            updateTextField(sender, model: substrateDerivationPathModel)
        } else if sender == ethereumDerivationPathField {
            updateTextField(sender, model: ethereumDerivationPathModel)
        }

        updateNextButton()
    }

    @objc private func actionUpload() {
        presenter.activateUpload()
    }

    @objc private func actionOpenSourceType() {
        if sourceTypeView.actionControl.isActivated {
            presenter.selectSourceType()
        }
    }

    @objc private func actionOpenCryptoType() {
        if substrateCryptoTypeView.actionControl.isActivated {
            presenter.selectCryptoType()
        }
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }
}

// MARK: - AccountImportViewProtocol

extension AccountImportViewController: AccountImportViewProtocol {
    func setSelectedNetwork(model _: SelectableViewModel<IconWithTitleViewModel>) {
        // FIXME: Remove function
    }

    func setSource(type: AccountImportSource) {
        switch type {
        case .mnemonic:
            passwordView.isHidden = true
            passwordTextField.text = nil
            passwordViewModel = nil

            substrateDerivationPathView.isHidden = false
            ethereumCryptoTypeView.isHidden = false
            ethereumDerivationPathView.isHidden = false

            uploadView.isHidden = true

            textContainerView.isHidden = false

        case .seed:
            passwordView.isHidden = true
            passwordTextField.text = nil
            passwordViewModel = nil

            substrateDerivationPathView.isHidden = false
            ethereumCryptoTypeView.isHidden = true
            ethereumDerivationPathView.isHidden = true

            uploadView.isHidden = true

            textContainerView.isHidden = false

        case .keystore:
            passwordView.isHidden = false

            substrateDerivationPathView.isHidden = true
            ethereumCryptoTypeView.isHidden = true
            ethereumDerivationPathView.isHidden = true

            uploadView.isHidden = false

            textContainerView.isHidden = true
            textView.text = nil
        }

        warningView.isHidden = true

        advancedControl.deactivate(animated: false)
        advancedContainerView.isHidden = true

        let locale = localizationManager?.selectedLocale ?? Locale.current

        sourceTypeView.actionControl.contentView.subtitleLabelView.text = type.titleForLocale(locale)

        substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        substrateCryptoTypeView.actionControl.invalidateLayout()
    }

    func setSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel

        if !uploadView.isHidden {
            updateUploadView()
        } else {
            textPlaceholderLabel.text = viewModel.placeholder
            textView.text = viewModel.inputHandler.value
        }

        updateTextViewPlaceholder()
        updateNextButton()
    }

    func setName(viewModel: InputViewModelProtocol) {
        usernameViewModel = viewModel

        usernameTextField.text = viewModel.inputHandler.value

        updateNextButton()
    }

    func setPassword(viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel

        passwordTextField.text = viewModel.inputHandler.value

        updateNextButton()
    }

    func setSelectedCrypto(model: SelectableViewModel<TitleWithSubtitleViewModel>) {
        let title = "\(model.underlyingViewModel.title) | \(model.underlyingViewModel.subtitle)"

        substrateCryptoTypeView.actionControl.contentView.subtitleLabelView.text = title

        substrateCryptoTypeView.actionControl.showsImageIndicator = model.selectable
        substrateCryptoTypeView.isUserInteractionEnabled = model.selectable

        if model.selectable {
            substrateCryptoTypeView.applyEnabledStyle()
        } else {
            substrateCryptoTypeView.applyDisabledStyle()
        }

        substrateCryptoTypeView.actionControl.contentView.invalidateLayout()
        substrateCryptoTypeView.actionControl.invalidateLayout()
    }

    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol) {
        substrateDerivationPathModel = viewModel
        setDerivationPath(viewModel: viewModel, for: substrateDerivationPathField)
    }

    func setEthereumDerivationPath(viewModel: InputViewModelProtocol) {
        ethereumDerivationPathModel = viewModel
        setDerivationPath(viewModel: viewModel, for: ethereumDerivationPathField)
    }

    func setUploadWarning(message: String) {
        warningLabel.text = message
        warningView.isHidden = false
    }

    func didCompleteSourceTypeSelection() {
        sourceTypeView.actionControl.deactivate(animated: true)
    }

    func didCompleteCryptoTypeSelection() {
        substrateCryptoTypeView.actionControl.deactivate(animated: true)
    }

    func didCompleteAddressTypeSelection() {
        // FIXME: Remove this function
    }

    func didValidateSubstrateDerivationPath(_ status: FieldStatus) {
        updateSubstrateDerivationPath(status: status)
    }

    func didValidateEthereumDerivationPath(_ status: FieldStatus) {
        updateEthereumDerivationPath(status: status)
    }
}

// MARK: - UITextFieldDelegate

extension AccountImportViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        presenter.validateDerivationPath()

        return false
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        var viewModel: InputViewModelProtocol?

        if textField == substrateDerivationPathField {
            viewModel = substrateDerivationPathModel
        } else if textField == ethereumDerivationPathField {
            viewModel = ethereumDerivationPathModel
        }

        guard let viewModel = viewModel else { return true }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}

// MARK: - AnimatedTextFieldDelegate

extension AccountImportViewController: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let viewModel: InputViewModelProtocol?

        if textField === usernameTextField {
            viewModel = usernameViewModel
        } else {
            viewModel = passwordViewModel
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

// MARK: - UITextViewDelegate

extension AccountImportViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView.text != sourceViewModel?.inputHandler.value {
            textView.text = sourceViewModel?.inputHandler.value
        }

        updateTextViewPlaceholder()
        updateNextButton()
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if text == String.returnKey {
            textView.resignFirstResponder()
            return false
        }

        guard let model = sourceViewModel else {
            return false
        }

        let shouldApply = model.inputHandler.didReceiveReplacement(text, for: range)

        if !shouldApply, textView.text != model.inputHandler.value {
            textView.text = model.inputHandler.value
        }

        return shouldApply
    }
}

// MARK: - KeyboardAdoptable

extension AccountImportViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if textView.isFirstResponder {
                targetView = textView
            } else if usernameTextField.isFirstResponder {
                targetView = usernameView
            } else if passwordTextField.isFirstResponder {
                targetView = passwordView
            } else if substrateDerivationPathField.isFirstResponder {
                targetView = substrateDerivationPathView
            } else if ethereumDerivationPathField.isFirstResponder {
                targetView = ethereumDerivationPathView
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

// MARK: - Localizable

extension AccountImportViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
