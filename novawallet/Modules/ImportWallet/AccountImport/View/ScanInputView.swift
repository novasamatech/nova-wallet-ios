import UIKit
import UIKit_iOS
import Foundation_iOS

protocol ScanInputViewDelegate: AnyObject {
    func scanInputViewWillStartEditing(_ inputView: ScanInputView)
    func scanInputViewShouldReturn(_ inputView: ScanInputView) -> Bool
    func scanInputViewDidEndEditing(_ inputView: ScanInputView)
    func scanInputViewShouldClearOnBackspace(_ inputView: ScanInputView) -> Bool
}

class ScanInputView: BackgroundedContentControl {
    let textField: UITextField = {
        let textField = UITextField()
        textField.font = .regularSubheadline
        textField.textColor = R.color.colorTextPrimary()
        textField.tintColor = R.color.colorTextPrimary()
        textField.clearButtonMode = .never

        var attributes = textField.defaultTextAttributes
        let currentStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        let paragraphStyle = (currentStyle?.mutableCopy() as? NSMutableParagraphStyle) ??
            NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingMiddle

        attributes[.paragraphStyle] = paragraphStyle
        textField.defaultTextAttributes = attributes

        textField.keyboardType = .default
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none

        return textField
    }()

    weak var delegate: ScanInputViewDelegate?

    let scanButton: RoundedButton = {
        let button = RoundedButton()
        button.applyAccessoryStyle()

        let icon = R.image.iconTransferScan()?.tinted(with: R.color.colorIconAccent()!)
        button.imageWithTitleView?.iconImage = icon
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = 0
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 8.0, bottom: 6.0, right: 8.0)

        return button
    }()

    let clearButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconStyle()

        let icon = R.image.iconClearField()?.tinted(with: R.color.colorIconSecondary()!)
        button.imageWithTitleView?.iconImage = icon
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = 0
        button.contentInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)

        return button
    }()

    var localizablePlaceholder: LocalizableResource<String> = LocalizableResource { locale in
        R.string(preferredLanguages: locale.rLanguages).localizable.commonAddress()
    } {
        didSet {
            setupPlaceholder()
        }
    }

    private let stackView: UIStackView = {
        let view = UIStackView()
        view.spacing = 8.0
        view.axis = .horizontal
        view.alignment = .fill
        return view
    }()

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    private var inputViewModel: InputViewModelProtocol?

    var completed: Bool {
        if let inputViewModel = inputViewModel {
            return inputViewModel.inputHandler.completed
        } else {
            return false
        }
    }

    private var hasText: Bool {
        if let text = textField.text, !text.isEmpty {
            return true
        } else {
            return false
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 48.0)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        setupLocalization()
    }

    func bind(inputViewModel: InputViewModelProtocol) {
        if textField.text != inputViewModel.inputHandler.value {
            textField.text = inputViewModel.inputHandler.value
        }

        self.inputViewModel = inputViewModel

        updateControlsState()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutContent()
    }
}

// MARK: - Private

private extension ScanInputView {
    func setupLocalization() {
        setupPlaceholder()

        setNeedsLayout()
    }

    func setupPlaceholder() {
        let placeholder = localizablePlaceholder.value(for: locale)

        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )
    }

    func layoutContent() {
        let buttonHeight: CGFloat = 32.0
        var actionsWidth: CGFloat = 0

        if !scanButton.isHidden {
            actionsWidth += scanButton.intrinsicContentSize.width
        }

        if !clearButton.isHidden {
            actionsWidth += !scanButton.isHidden ? stackView.spacing : 0
            actionsWidth += clearButton.intrinsicContentSize.width
        }

        stackView.frame = CGRect(
            x: bounds.maxX - contentInsets.right - actionsWidth,
            y: bounds.midY - buttonHeight / 2.0,
            width: actionsWidth,
            height: buttonHeight
        )

        let rightFieldSpacing: CGFloat = 8.0
        let fieldWidth: CGFloat

        if actionsWidth > 0 {
            fieldWidth = max(
                stackView.frame.minX - bounds.minX - contentInsets.left - rightFieldSpacing,
                0
            )
        } else {
            fieldWidth = max(
                stackView.frame.minX - bounds.minX - contentInsets.left,
                0
            )
        }

        let fieldHeight = textField.intrinsicContentSize.height

        textField.frame = CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.midY - fieldHeight / 2.0,
            width: fieldWidth,
            height: fieldHeight
        )
    }

    func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        configureLocalHandlers()
        configureTextFieldHandlers()
        configureClearHandlers()

        updateControlsState()
    }

    func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let roundedView = RoundedView()
            roundedView.isUserInteractionEnabled = false
            roundedView.apply(style: .strokeOnEditing)

            backgroundView = roundedView
        }
    }

    func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        addSubview(textField)

        stackView.addArrangedSubview(scanButton)
        stackView.addArrangedSubview(clearButton)

        addSubview(stackView)

        contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)
    }

    func configureLocalHandlers() {
        addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)
    }

    func configureTextFieldHandlers() {
        textField.addTarget(
            self,
            action: #selector(actionEditingChanged(_:)),
            for: .editingChanged
        )

        textField.addTarget(
            self,
            action: #selector(actionEditingBeginEnd),
            for: .editingDidBegin
        )
        textField.addTarget(
            self,
            action: #selector(actionEditingBeginEnd),
            for: .editingDidEnd
        )

        textField.delegate = self
    }

    func configureClearHandlers() {
        clearButton.addTarget(
            self,
            action: #selector(actionClear),
            for: .touchUpInside
        )
    }

    func updateControlsState() {
        let oldStates = stackView.arrangedSubviews.map(\.isHidden)

        if hasText {
            clearButton.isHidden = false
            scanButton.isHidden = true
        } else {
            clearButton.isHidden = true
            scanButton.isHidden = false
        }

        let newStates = stackView.arrangedSubviews.map(\.isHidden)

        if oldStates != newStates {
            setNeedsLayout()
        }
    }

    @objc func actionTouchUpInside() {
        textField.becomeFirstResponder()
    }

    @objc func actionEditingChanged(_ sender: UITextField) {
        if inputViewModel?.inputHandler.value != sender.text {
            sender.text = inputViewModel?.inputHandler.value
        }

        updateControlsState()

        sendActions(for: .editingChanged)
    }

    @objc func actionClear() {
        guard hasText else { return }

        textField.text = ""
        inputViewModel?.inputHandler.changeValue(to: "")

        updateControlsState()

        sendActions(for: .editingChanged)
    }

    @objc func actionEditingBeginEnd() {
        roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0.0

        updateControlsState()
    }
}

extension ScanInputView: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if string.isEmpty, range.length > 0, hasText {
            let shouldClearAll = delegate?.scanInputViewShouldClearOnBackspace(self) ?? false

            if shouldClearAll {
                textField.text = ""
                inputViewModel?.inputHandler.changeValue(to: "")

                updateControlsState()
                sendActions(for: .editingChanged)

                return false
            }
        }

        guard let inputViewModel = inputViewModel else {
            return true
        }

        let shouldApply = inputViewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != inputViewModel.inputHandler.value {
            textField.text = inputViewModel.inputHandler.value
        }

        return shouldApply
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        inputViewModel?.inputHandler.changeValue(to: "")

        return true
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        guard let delegate else {
            textField.resignFirstResponder()
            return true
        }

        return delegate.scanInputViewShouldReturn(self)
    }

    func textFieldShouldBeginEditing(_: UITextField) -> Bool {
        delegate?.scanInputViewWillStartEditing(self)
        return true
    }

    func textFieldDidEndEditing(_: UITextField, reason _: UITextField.DidEndEditingReason) {
        delegate?.scanInputViewDidEndEditing(self)
    }
}
