import UIKit
import UIKit_iOS
import Foundation_iOS

class TextInputView: BackgroundedContentControl {
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
        paragraphStyle.lineBreakMode = .byTruncatingTail

        attributes[.paragraphStyle] = paragraphStyle
        textField.defaultTextAttributes = attributes

        textField.keyboardType = .default
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none

        return textField
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

    var shouldUseClearButton: Bool = true {
        didSet {
            applyControlsState()
        }
    }

    let stackView: UIStackView = {
        let view = UIStackView()
        view.spacing = 8.0
        view.axis = .horizontal
        view.alignment = .fill
        return view
    }()

    weak var delegate: TextInputViewDelegate?

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    private(set) var inputViewModel: InputViewModelProtocol?

    var completed: Bool {
        if let inputViewModel = inputViewModel {
            return inputViewModel.inputHandler.completed
        } else {
            return false
        }
    }

    var hasText: Bool {
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
    }

    func bind(inputViewModel: InputViewModelProtocol) {
        if textField.text != inputViewModel.inputHandler.value {
            textField.text = inputViewModel.inputHandler.value
        }

        if !inputViewModel.placeholder.isEmpty {
            textField.placeholder = inputViewModel.placeholder
        }

        textField.isEnabled = inputViewModel.inputHandler.enabled

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

    func applyingActionWidth(for currentWidth: CGFloat) -> CGFloat {
        if !clearButton.isHidden {
            return currentWidth + clearButton.intrinsicContentSize.width
        } else {
            return currentWidth
        }
    }

    private func layoutContent() {
        let buttonHeight: CGFloat = 32.0
        let actionsWidth: CGFloat = applyingActionWidth(for: 0)

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
                stackView.frame.minX - contentInsets.left - rightFieldSpacing,
                0
            )
        } else {
            fieldWidth = max(stackView.frame.minX - contentInsets.left, 0)
        }

        let fieldHeight = textField.intrinsicContentSize.height

        textField.frame = CGRect(
            x: contentInsets.left,
            y: bounds.midY - fieldHeight / 2.0,
            width: fieldWidth,
            height: fieldHeight
        )
    }

    // MARK: Configure

    func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        configureLocalHandlers()
        configureTextFieldHandlers()
        configureClearHandlers()

        updateControlsState()
    }

    private func configureBackgroundViewIfNeeded() {
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

        stackView.addArrangedSubview(clearButton)

        addSubview(stackView)

        contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)
    }

    private func configureTextFieldHandlers() {
        textField.addTarget(self, action: #selector(actionEditingBeginEnd), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(actionEditingBeginEnd), for: .editingDidEnd)
        textField.addTarget(
            self,
            action: #selector(actionEditingChanged(_:)),
            for: .editingChanged
        )

        textField.delegate = self
    }

    private func configureClearHandlers() {
        clearButton.addTarget(
            self,
            action: #selector(actionClear),
            for: .touchUpInside
        )
    }

    private func configureLocalHandlers() {
        addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)
    }

    func applyControlsState() {
        if shouldUseClearButton, hasText, textField.isEnabled {
            clearButton.isHidden = false
        } else {
            clearButton.isHidden = true
        }
    }

    func updateControlsState() {
        let oldStates = stackView.arrangedSubviews.map(\.isHidden)

        applyControlsState()

        let newStates = stackView.arrangedSubviews.map(\.isHidden)

        if oldStates != newStates {
            setNeedsLayout()
        }
    }

    // MARK: Action

    @objc private func actionEditingChanged(_ sender: UITextField) {
        if inputViewModel?.inputHandler.value != sender.text {
            sender.text = inputViewModel?.inputHandler.value
        }

        updateControlsState()

        sendActions(for: .editingChanged)
    }

    @objc private func actionEditingBeginEnd() {
        roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0

        updateControlsState()
    }

    @objc private func actionTouchUpInside() {
        textField.becomeFirstResponder()
    }

    @objc func actionClear() {
        guard hasText else {
            return
        }

        textField.text = ""
        inputViewModel?.inputHandler.changeValue(to: "")

        updateControlsState()

        sendActions(for: .editingChanged)
    }
}

extension TextInputView: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
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
        if let delegate = delegate {
            return delegate.textInputViewShouldReturn(self)
        } else {
            textField.resignFirstResponder()
            return true
        }
    }

    func textFieldShouldBeginEditing(_: UITextField) -> Bool {
        delegate?.textInputViewWillStartEditing(self)
        return true
    }
}
