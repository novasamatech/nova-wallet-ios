import UIKit
import SoraUI
import SoraFoundation
import SwiftUI

protocol AccountImportKeystoreViewDelegate: AnyObject {
    func accountImportKeystoreViewDidProceed(_ view: AccountImportKeystoreView)
    func accountImportKeystoreViewDidUpload(_ view: AccountImportKeystoreView)
}

final class AccountImportKeystoreView: AccountImportBaseView {
    weak var delegate: AccountImportKeystoreViewDelegate?

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let uploadWarningView: IconDetailsView = {
        let view = IconDetailsView()
        view.imageView.image = R.image.iconWarning()
        view.detailsLabel.textColor = R.color.colorLightGray()
        view.detailsLabel.font = .p1Paragraph
        return view
    }()

    let uploadView: DetailsTriangularedView = {
        let view = UIFactory.default.createDetailsView(
            with: .largeIconTitleSubtitle,
            filled: false
        )

        view.actionImage = R.image.iconUpload()
        view.highlightedFillColor = R.color.colorAccentSelected()!

        return view
    }()

    let passwordBackroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let passwordView: AnimatedTextField = {
        let view = UIFactory.default.createAnimatedTextField()

        return view
    }()

    let eyeButton: RoundedButton = {
        let button = RoundedButton()
        button.roundedBackgroundView?.fillColor = .clear
        button.roundedBackgroundView?.highlightedFillColor = .clear
        button.roundedBackgroundView?.strokeColor = .clear
        button.roundedBackgroundView?.highlightedStrokeColor = .clear
        button.roundedBackgroundView?.shadowOpacity = 0.0
        button.imageWithTitleView?.iconImage = R.image.iconEye()
        return button
    }()

    let usernameBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let usernameTextField: AnimatedTextField = UIFactory.default.createAnimatedTextField()

    let usernameHintLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    let proceedButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindSource(viewModel: InputViewModelProtocol) {
        sourceViewModel = viewModel
        updateUploadView()

        updateProceedButton()
    }

    func bindPassword(viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel
        passwordView.text = viewModel.inputHandler.value

        updateProceedButton()
    }

    func setUploadWarning(message: String) {
        uploadWarningView.isHidden = false
        uploadWarningView.detailsLabel.text = message

        setNeedsLayout()
    }

    func resetUploadWarning() {
        uploadWarningView.isHidden = true
    }

    func bindUsername(viewModel: InputViewModelProtocol?) {
        usernameViewModel = viewModel
        usernameTextField.text = viewModel?.inputHandler.value

        updateProceedButton()
    }

    override func setupLocalization() {
        titleLabel.text = "Provide your Restore JSON"
        uploadView.titleLabel.text = "Restore JSON"

        passwordView.title = R.string.localizable
            .accountImportPasswordPlaceholder(preferredLanguages: locale?.rLanguages)

        usernameTextField.title = R.string.localizable.walletUsernameSetupChooseTitle(
            preferredLanguages: locale?.rLanguages
        )

        usernameHintLabel.text = R.string.localizable.walletNicknameCreateCaption(
            preferredLanguages: locale?.rLanguages
        )

        updateUploadView()
    }

    private func setupHandlers() {
        proceedButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)

        usernameTextField.textField.returnKeyType = .done
        usernameTextField.textField.textContentType = .nickname
        usernameTextField.textField.autocapitalizationType = .sentences
        usernameTextField.textField.autocorrectionType = .no
        usernameTextField.textField.spellCheckingType = .no

        usernameTextField.delegate = self

        usernameTextField.addTarget(self, action: #selector(actionTextFieldChanged(_:)), for: .editingChanged)

        passwordView.textField.returnKeyType = .done
        passwordView.textField.textContentType = .password
        passwordView.textField.autocapitalizationType = .sentences
        passwordView.textField.autocorrectionType = .no
        passwordView.textField.spellCheckingType = .no
        passwordView.textField.isSecureTextEntry = true

        passwordView.delegate = self

        passwordView.addTarget(self, action: #selector(actionTextFieldChanged(_:)), for: .editingChanged)

        uploadView.addTarget(self, action: #selector(actionUpload), for: .touchUpInside)

        eyeButton.addTarget(self, action: #selector(actionToggleSecurity), for: .touchUpInside)
    }

    private func updateUploadView() {
        if let viewModel = sourceViewModel, !viewModel.inputHandler.normalizedValue.isEmpty {
            uploadView.subtitleLabel?.textColor = R.color.colorWhite()
            uploadView.subtitle = viewModel.inputHandler.normalizedValue
        } else {
            uploadView.subtitleLabel?.textColor = R.color.colorLightGray()

            uploadView.subtitle = R.string.localizable.recoverJsonHint(preferredLanguages: locale?.rLanguages)
        }
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide).inset(UIConstants.verticalTitleInset)
        }

        let uploadStackView = AccountImportKeystoreView.vStack(
            alignment: .fill,
            distribution: .fill,
            spacing: 16.0,
            [uploadWarningView, uploadView]
        )

        addSubview(uploadStackView)
        uploadStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(24.0)
        }

        uploadView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        uploadWarningView.isHidden = true

        addSubview(passwordBackroundView)
        passwordBackroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(uploadView.snp.bottom).offset(16.0)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        passwordBackroundView.addSubview(eyeButton)
        eyeButton.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.width.equalTo(UIConstants.triangularedViewHeight)
        }

        passwordBackroundView.addSubview(passwordView)
        passwordView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(eyeButton.snp.leading)
        }

        addSubview(usernameBackgroundView)
        usernameBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(passwordView.snp.bottom).offset(16.0)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        usernameBackgroundView.addSubview(usernameTextField)
        usernameTextField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(usernameHintLabel)
        usernameHintLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(usernameBackgroundView.snp.bottom).offset(12.0)
        }

        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func updateProceedButton() {
        if let viewModel = sourceViewModel, viewModel.inputHandler.required, viewModel.inputHandler.value.isEmpty {
            proceedButton.applyDisabledStyle()
            proceedButton.imageWithTitleView?.title = "Provide your Restore Json..."
        } else if let viewModel = passwordViewModel, viewModel.inputHandler.required,
                  (passwordView.text ?? "").isEmpty {
            proceedButton.applyDisabledStyle()
            proceedButton.imageWithTitleView?.title = "Enter password..."
        } else if let viewModel = usernameViewModel, viewModel.inputHandler.required,
                  (usernameTextField.text ?? "").isEmpty {
            proceedButton.applyDisabledStyle()
            proceedButton.imageWithTitleView?.title = "Enter wallet name..."
        } else {
            proceedButton.applyEnabledStyle()
            proceedButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
                preferredLanguages: locale?.rLanguages
            )
        }
    }

    private func updateTextField(_ textField: UITextField, model: InputViewModelProtocol?) {
        if model?.inputHandler.value != textField.text {
            textField.text = model?.inputHandler.value
        }
    }

    @objc private func actionProceed() {
        delegate?.accountImportKeystoreViewDidProceed(self)
    }

    @objc private func actionUpload() {
        delegate?.accountImportKeystoreViewDidUpload(self)
    }

    @objc private func actionTextFieldChanged(_ sender: UITextField) {
        if sender == usernameTextField {
            updateTextField(sender, model: usernameViewModel)
        } else if sender == passwordView {
            updateTextField(sender, model: passwordViewModel)
        }

        updateProceedButton()
    }

    @objc private func actionToggleSecurity() {
        let isSecure = !passwordView.textField.isSecureTextEntry

        if isSecure {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconEye()
        } else {
            eyeButton.imageWithTitleView?.iconImage = R.image.iconNoEye()
        }

        passwordView.textField.isSecureTextEntry = isSecure
    }
}

extension AccountImportKeystoreView: AnimatedTextFieldDelegate {
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
