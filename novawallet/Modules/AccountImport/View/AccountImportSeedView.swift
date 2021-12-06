import UIKit
import SoraUI
import SoraFoundation

protocol AccountImportSeedViewDelegate: AnyObject {
    func accountImportSeedViewDidProceed(_ view: AccountImportSeedView)
}

final class AccountImportSeedView: AccountImportBaseView {
    weak var delegate: AccountImportSeedViewDelegate?

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.alignment = .fill
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(
            top: UIConstants.verticalTitleInset,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h2Title
        label.numberOfLines = 0
        return label
    }()

    let seedBackgroundView: RoundedView = UIFactory.default.createRoundedBackgroundView()

    let seedTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        return label
    }()

    let seedHintLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        return label
    }()

    let seedTextView: UITextView = {
        let view = UITextView()
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.tintColor = R.color.colorWhite()
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        return view
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
        seedTextView.text = viewModel.inputHandler.value
        seedHintLabel.text = viewModel.placeholder

        updateProceedButton()
    }

    func bindUsername(viewModel: InputViewModelProtocol?) {
        usernameViewModel = viewModel
        usernameTextField.text = viewModel?.inputHandler.value

        let isHidden = viewModel == nil
        usernameBackgroundView.isHidden = isHidden
        usernameHintLabel.isHidden = isHidden

        updateProceedButton()
    }

    override func setupLocalization() {
        titleLabel.text = R.string.localizable.walletImportSeedTitle(
            preferredLanguages: locale?.rLanguages
        )
        seedTitleLabel.text = R.string.localizable.importRawSeed(preferredLanguages: locale?.rLanguages)

        usernameTextField.title = R.string.localizable.walletUsernameSetupChooseTitle_v2_2_0(
            preferredLanguages: locale?.rLanguages
        )

        usernameHintLabel.text = R.string.localizable.walletNicknameCreateCaption_v2_2_0(
            preferredLanguages: locale?.rLanguages
        )

        updateProceedButton()
    }

    override func updateOnAppear() {
        seedTextView.becomeFirstResponder()
    }

    override func updateOnKeyboardBottomInsetChange(_ newInset: CGFloat) {
        let scrollViewOffset = bounds.height - containerView.frame.maxY

        var contentInsets = containerView.scrollView.contentInset
        contentInsets.bottom = max(0.0, newInset - scrollViewOffset)
        containerView.scrollView.contentInset = contentInsets

        if contentInsets.bottom > 0.0 {
            let targetView: UIView?

            if seedTextView.isFirstResponder {
                targetView = seedBackgroundView
            } else if usernameTextField.isFirstResponder {
                targetView = usernameBackgroundView
            } else {
                targetView = nil
            }

            if let firstResponderView = targetView {
                let fieldFrame = containerView.scrollView.convert(
                    firstResponderView.frame,
                    from: firstResponderView.superview
                )

                containerView.scrollView.scrollRectToVisible(fieldFrame, animated: true)
            }
        }
    }

    private func setupHandlers() {
        proceedButton.addTarget(self, action: #selector(actionProceed), for: .touchUpInside)

        seedTextView.returnKeyType = .done
        seedTextView.textContentType = .none
        seedTextView.autocapitalizationType = .none
        seedTextView.autocorrectionType = .no
        seedTextView.spellCheckingType = .no
        seedTextView.delegate = self

        usernameTextField.textField.returnKeyType = .done
        usernameTextField.textField.textContentType = .nickname
        usernameTextField.textField.autocapitalizationType = .sentences
        usernameTextField.textField.autocorrectionType = .no
        usernameTextField.textField.spellCheckingType = .no

        usernameTextField.delegate = self

        usernameTextField.addTarget(self, action: #selector(actionTextFieldChanged(_:)), for: .editingChanged)
    }

    private func setupLayout() {
        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(proceedButton.snp.top).offset(-16.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.setCustomSpacing(24.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(seedBackgroundView)

        seedBackgroundView.addSubview(seedTitleLabel)
        seedTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.leading.equalToSuperview().inset(16.0)
        }

        seedBackgroundView.addSubview(seedHintLabel)
        seedHintLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.leading.greaterThanOrEqualTo(seedTitleLabel.snp.trailing).offset(4.0)
        }

        seedBackgroundView.addSubview(seedTextView)
        seedTextView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(20)
            make.leading.trailing.equalToSuperview().inset(12.0)
            make.height.greaterThanOrEqualTo(36.0)
        }

        seedBackgroundView.snp.makeConstraints { make in
            make.height.equalTo(seedTextView).offset(32.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: seedBackgroundView)

        containerView.stackView.addArrangedSubview(usernameBackgroundView)
        usernameBackgroundView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        usernameBackgroundView.addSubview(usernameTextField)
        usernameTextField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.stackView.setCustomSpacing(12.0, after: usernameBackgroundView)

        containerView.stackView.addArrangedSubview(usernameHintLabel)
    }

    private func updateProceedButton() {
        if let viewModel = sourceViewModel, viewModel.inputHandler.required, seedTextView.text.isEmpty {
            proceedButton.applyDisabledStyle()
            proceedButton.isUserInteractionEnabled = false
            proceedButton.imageWithTitleView?.title = R.string.localizable.walletImportNoSeedTitle(
                preferredLanguages: locale?.rLanguages
            )
        } else if let viewModel = usernameViewModel, viewModel.inputHandler.required,
                  (usernameTextField.text ?? "").isEmpty {
            proceedButton.applyDisabledStyle()
            proceedButton.isUserInteractionEnabled = false
            proceedButton.imageWithTitleView?.title = R.string.localizable.walletImportNoNameTitle(
                preferredLanguages: locale?.rLanguages
            )
        } else {
            proceedButton.applyEnabledStyle()
            proceedButton.isUserInteractionEnabled = true
            proceedButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
                preferredLanguages: locale?.rLanguages
            )
        }
    }

    @objc private func actionProceed() {
        delegate?.accountImportSeedViewDidProceed(self)
    }

    @objc private func actionTextFieldChanged(_ sender: UITextField) {
        if usernameViewModel?.inputHandler.value != sender.text {
            sender.text = usernameViewModel?.inputHandler.value
        }

        updateProceedButton()
    }
}

extension AccountImportSeedView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView.text != sourceViewModel?.inputHandler.value {
            textView.text = sourceViewModel?.inputHandler.value
        }

        updateProceedButton()
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

extension AccountImportSeedView: AnimatedTextFieldDelegate {
    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let currentViewModel = usernameViewModel else {
            return true
        }

        let shouldApply = currentViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != currentViewModel.inputHandler.value {
            textField.text = currentViewModel.inputHandler.value
        }

        return shouldApply
    }
}
