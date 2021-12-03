import UIKit
import SoraFoundation
import SoraUI

final class AdvancedWalletViewController: UIViewController, ViewHolder {
    typealias RootViewType = AdvancedWalletViewLayout

    let presenter: AdvancedWalletPresenterProtocol
    let readonly: Bool

    private var substrateDerivationPathViewModel: InputViewModelProtocol?
    private var ethereumDerivationPathViewModel: InputViewModelProtocol?

    var keyboardHandler: KeyboardHandler?

    init(
        presenter: AdvancedWalletPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        readonly: Bool
    ) {
        self.presenter = presenter
        self.readonly = readonly
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AdvancedWalletViewLayout()

        if !readonly {
            rootView.setupApplyButton()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        setupTextField(rootView.substrateTextField)
        setupTextField(rootView.ethereumTextField)

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

    private func setupHandlers() {
        rootView.substrateCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOnSubstrateCryptoType),
            for: .touchUpInside
        )

        rootView.ethereumCryptoTypeView.actionControl.addTarget(
            self,
            action: #selector(actionOnEthereumCryptoType),
            for: .touchUpInside
        )

        rootView.substrateTextField.delegate = self

        rootView.substrateTextField.addTarget(
            self,
            action: #selector(actionFieldChanged(sender:)),
            for: .editingChanged
        )

        rootView.ethereumTextField.delegate = self

        rootView.ethereumTextField.addTarget(
            self,
            action: #selector(actionFieldChanged(sender:)),
            for: .editingChanged
        )

        rootView.applyButton?.addTarget(self, action: #selector(actionApply), for: .touchUpInside)
    }

    private func setupTextField(_ textField: UITextField) {
        textField.returnKeyType = .done
        textField.textContentType = .none
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
    }

    private func setupLocalization() {
        title = R.string.localizable.commonAdvanced(preferredLanguages: selectedLocale.rLanguages)

        let substrateCryptoView = rootView.substrateCryptoTypeView.actionControl.contentView
        substrateCryptoView?.titleLabel.text = R.string.localizable.commonCryptoTypeSubstrate(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.substrateTitleLabel.text = R.string.localizable.commonSecretDerivationPathSubstrate(
            preferredLanguages: selectedLocale.rLanguages
        )

        let ethereumCryptoView = rootView.ethereumCryptoTypeView.actionControl.contentView
        ethereumCryptoView?.titleLabel.text = R.string.localizable.commonCryptoTypeEthereum(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.ethereumTitleLabel.text = R.string.localizable.commonSecretDerivationPathEthereum(
            preferredLanguages: selectedLocale.rLanguages
        )

        if let applyButton = rootView.applyButton {
            applyButton.imageWithTitleView?.title = R.string.localizable.commonApply(
                preferredLanguages: selectedLocale.rLanguages
            )
        }
    }

    private func applyDerivationPathStyle(_ isEnabled: Bool, to derivationPathView: RoundedView) {
        derivationPathView.isUserInteractionEnabled = isEnabled

        if isEnabled {
            derivationPathView.applyEnabledBackgroundStyle()
        } else {
            derivationPathView.applyDisabledBackgroundStyle()
        }
    }

    private func applyCryptoTypeStyle(_ isEnabled: Bool, to actionView: BorderedSubtitleActionView) {
        if isEnabled {
            actionView.applyEnabledStyle()
            actionView.actionControl.imageIndicator.image = R.image.iconSmallArrowDown()
            actionView.isUserInteractionEnabled = true
        } else {
            actionView.applyDisabledStyle()
            actionView.actionControl.imageIndicator.image = nil
            actionView.isUserInteractionEnabled = false
        }
    }

    private func applyCryptoType(
        viewModel: SelectableViewModel<TitleWithSubtitleViewModel>?,
        to cryptoTypeView: BorderedSubtitleActionView
    ) {
        if let viewModel = viewModel {
            cryptoTypeView.isHidden = false
            applyCryptoTypeStyle(viewModel.selectable && !readonly, to: cryptoTypeView)

            let contentView = cryptoTypeView.actionControl.contentView

            let text = "\(viewModel.underlyingViewModel.title) | \(viewModel.underlyingViewModel.subtitle)"
            contentView?.subtitleLabelView.text = text
        } else {
            cryptoTypeView.isHidden = true
        }
    }

    private func updateTextField(_ textField: UITextField, model: InputViewModelProtocol?) {
        if model?.inputHandler.value != textField.text {
            textField.text = model?.inputHandler.value
        }
    }

    private func updateApplyButton() {
        guard let applyButton = rootView.applyButton else {
            return
        }

        if
            let viewModel = substrateDerivationPathViewModel,
            viewModel.inputHandler.required,
            (rootView.substrateTextField.text ?? "").isEmpty {
            applyButton.applyDisabledStyle()
            applyButton.isUserInteractionEnabled = false
        } else if
            let viewModel = ethereumDerivationPathViewModel,
            viewModel.inputHandler.required,
            (rootView.ethereumTextField.text ?? "").isEmpty {
            applyButton.applyDisabledStyle()
            applyButton.isUserInteractionEnabled = false
        } else {
            applyButton.applyEnabledStyle()
            applyButton.isUserInteractionEnabled = true
        }
    }

    @objc private func actionApply() {
        presenter.apply()
    }

    @objc private func actionOnSubstrateCryptoType() {
        presenter.selectSubstrateCryptoType()
    }

    @objc private func actionOnEthereumCryptoType() {
        presenter.selectSubstrateCryptoType()
    }

    @objc private func actionFieldChanged(sender: UITextField) {
        if sender == rootView.substrateTextField {
            updateTextField(sender, model: substrateDerivationPathViewModel)
        } else if sender == rootView.ethereumTextField {
            updateTextField(sender, model: ethereumDerivationPathViewModel)
        }

        updateApplyButton()
    }
}

extension AdvancedWalletViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let maybeViewModel = textField == rootView.substrateTextField ?
            substrateDerivationPathViewModel : ethereumDerivationPathViewModel

        guard let viewModel = maybeViewModel else { return true }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AdvancedWalletViewController: AdvancedWalletViewProtocol {
    func setSubstrateCrypto(viewModel: SelectableViewModel<TitleWithSubtitleViewModel>?) {
        applyCryptoType(viewModel: viewModel, to: rootView.substrateCryptoTypeView)
    }

    func setEthreumCrypto(viewModel: SelectableViewModel<TitleWithSubtitleViewModel>?) {
        applyCryptoType(viewModel: viewModel, to: rootView.ethereumCryptoTypeView)
    }

    func setSubstrateDerivationPath(viewModel: InputViewModelProtocol?) {
        substrateDerivationPathViewModel = viewModel

        if let viewModel = viewModel {
            let shouldHideReadonly = readonly && viewModel.inputHandler.value.isEmpty
            rootView.substrateBackgroundView.isHidden = shouldHideReadonly

            rootView.substrateTextField.attributedPlaceholder = NSAttributedString(
                string: viewModel.placeholder,
                attributes: [
                    .font: UIFont.p1Paragraph,
                    .foregroundColor: R.color.colorDarkGray()!
                ]
            )
            rootView.substrateTextField.text = viewModel.inputHandler.value

            applyDerivationPathStyle(!readonly, to: rootView.substrateBackgroundView)
        } else {
            rootView.substrateBackgroundView.isHidden = true
        }
    }

    func setEthereumDerivationPath(viewModel: InputViewModelProtocol?) {
        ethereumDerivationPathViewModel = viewModel

        if let viewModel = viewModel {
            let shouldHideReadonly = readonly && viewModel.inputHandler.value.isEmpty
            rootView.ethereumBackgroundView.isHidden = shouldHideReadonly

            rootView.ethereumTextField.attributedPlaceholder = NSAttributedString(
                string: viewModel.placeholder,
                attributes: [
                    .font: UIFont.p1Paragraph,
                    .foregroundColor: R.color.colorDarkGray()!
                ]
            )
            rootView.ethereumTextField.text = viewModel.inputHandler.value

            applyDerivationPathStyle(!readonly, to: rootView.ethereumBackgroundView)
        } else {
            rootView.ethereumBackgroundView.isHidden = true
        }
    }

    func didCompleteCryptoTypeSelection() {
        rootView.substrateCryptoTypeView.actionControl.imageIndicator.deactivate()
        rootView.ethereumCryptoTypeView.actionControl.imageIndicator.deactivate()
    }
}

extension AdvancedWalletViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY

        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            if rootView.substrateTextField.isFirstResponder {
                let fieldFrame = scrollView.convert(
                    rootView.substrateTextField.frame,
                    from: rootView.substrateTextField.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            } else if rootView.ethereumTextField.isFirstResponder {
                let fieldFrame = scrollView.convert(
                    rootView.ethereumTextField.frame,
                    from: rootView.ethereumTextField.superview
                )

                scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }
}

extension AdvancedWalletViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
