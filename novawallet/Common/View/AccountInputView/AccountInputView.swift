import UIKit
import UIKit_iOS
import Foundation_iOS

class AccountInputView: BackgroundedContentControl {
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

    var showsMyself: Bool {
        get {
            mySelfButton != nil
        }

        set {
            if newValue {
                setupMyselfButton()
            } else {
                clearMyselfButton()
            }
        }
    }

    private(set) var mySelfButton: RoundedButton?

    weak var delegate: AccountInputViewDelegate?

    let pasteButton: RoundedButton = {
        let button = RoundedButton()
        button.applyAccessoryStyle()
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)

        return button
    }()

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

    let pasteboardService = PasteboardHandler(pasteboard: UIPasteboard.general)

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    var iconSize = CGSize(width: 24.0, height: 24.0) {
        didSet {
            setNeedsLayout()
        }
    }

    let iconView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconAddressPlaceholder()
        return view
    }()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    private var fieldStateViewModel: AccountFieldStateViewModel?
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

    func bind(fieldStateViewModel: AccountFieldStateViewModel) {
        self.fieldStateViewModel?.icon?.cancel(on: iconView)
        self.fieldStateViewModel = fieldStateViewModel

        iconView.image = R.image.iconAddressPlaceholder()

        fieldStateViewModel.icon?.loadImage(on: iconView, targetSize: iconSize, animated: true)
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

    private func setupLocalization() {
        setupPlaceholder()

        pasteButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonPaste()

        setupMyselfLocalization()

        setNeedsLayout()
    }

    private func setupPlaceholder() {
        let placeholder = localizablePlaceholder.value(for: locale)

        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.regularSubheadline
            ]
        )
    }

    private func setupMyselfLocalization() {
        mySelfButton?.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonMyself()
    }

    private func layoutContent() {
        iconView.frame = CGRect(
            origin: CGPoint(
                x: bounds.minX + contentInsets.left,
                y: bounds.midY - iconSize.height / 2.0
            ),
            size: iconSize
        )

        let buttonHeight: CGFloat = 32.0
        var actionsWidth: CGFloat = 0

        if let mySelfButton = mySelfButton, !mySelfButton.isHidden {
            actionsWidth += mySelfButton.intrinsicContentSize.width
        }

        if !pasteButton.isHidden {
            actionsWidth += (mySelfButton?.isHidden == false) ? stackView.spacing : 0
            actionsWidth += pasteButton.intrinsicContentSize.width
        }

        if !scanButton.isHidden {
            actionsWidth += !pasteButton.isHidden ? stackView.spacing : 0
            actionsWidth += scanButton.intrinsicContentSize.width
        }

        if !clearButton.isHidden {
            actionsWidth += clearButton.intrinsicContentSize.width
        }

        stackView.frame = CGRect(
            x: bounds.maxX - contentInsets.right - actionsWidth,
            y: bounds.midY - buttonHeight / 2.0,
            width: actionsWidth,
            height: buttonHeight
        )

        let leftFieldSpacing: CGFloat = 12.0
        let rightFieldSpacing: CGFloat = 8.0
        let fieldWidth: CGFloat

        if actionsWidth > 0 {
            fieldWidth = max(
                stackView.frame.minX - iconView.frame.maxX - leftFieldSpacing - rightFieldSpacing,
                0
            )
        } else {
            fieldWidth = max(stackView.frame.minX - iconView.frame.maxX - leftFieldSpacing, 0)
        }

        let fieldHeight = textField.intrinsicContentSize.height

        textField.frame = CGRect(
            x: iconView.frame.maxX + leftFieldSpacing,
            y: bounds.midY - fieldHeight / 2.0,
            width: fieldWidth,
            height: fieldHeight
        )
    }

    // MARK: Configure

    private func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        configureLocalHandlers()
        configureTextFieldHandlers()
        configurePasteHandlers()
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

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        contentView?.addSubview(iconView)

        addSubview(textField)

        stackView.addArrangedSubview(pasteButton)
        stackView.addArrangedSubview(scanButton)
        stackView.addArrangedSubview(clearButton)

        addSubview(stackView)

        contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)
    }

    private func configureLocalHandlers() {
        addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)
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

    private func configurePasteHandlers() {
        pasteButton.addTarget(self, action: #selector(actionPaste), for: .touchUpInside)

        pasteboardService.delegate = self
    }

    private func configureClearHandlers() {
        clearButton.addTarget(
            self,
            action: #selector(actionClear),
            for: .touchUpInside
        )
    }

    private func updateControlsState() {
        let oldStates = stackView.arrangedSubviews.map(\.isHidden)

        if hasText {
            clearButton.isHidden = false
            pasteButton.isHidden = true
            scanButton.isHidden = true
            mySelfButton?.isHidden = true
        } else {
            clearButton.isHidden = true
            pasteButton.isHidden = !pasteboardService.pasteboard.hasStrings
            scanButton.isHidden = false
            mySelfButton?.isHidden = false
        }

        let newStates = stackView.arrangedSubviews.map(\.isHidden)

        if oldStates != newStates {
            setNeedsLayout()
        }
    }

    private func setupMyselfButton() {
        guard mySelfButton == nil else {
            return
        }

        let button = RoundedButton()
        button.applyAccessoryStyle()
        button.contentInsets = UIEdgeInsets(top: 6.0, left: 12.0, bottom: 6.0, right: 12.0)

        mySelfButton = button

        stackView.insertArrangedSubview(button, at: 0)

        mySelfButton?.isHidden = hasText

        setupMyselfLocalization()

        setNeedsLayout()
    }

    private func clearMyselfButton() {
        mySelfButton?.removeFromSuperview()
        mySelfButton = nil

        setNeedsLayout()
    }

    // MARK: Action

    @objc private func actionTouchUpInside() {
        textField.becomeFirstResponder()
    }

    @objc private func actionEditingChanged(_ sender: UITextField) {
        if inputViewModel?.inputHandler.value != sender.text {
            sender.text = inputViewModel?.inputHandler.value
        }

        updateControlsState()

        sendActions(for: .editingChanged)
    }

    @objc private func actionEditingBeginEnd() {
        roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0.0

        updateControlsState()
    }

    @objc func actionPaste() {
        if
            let pasteString = pasteboardService.pasteboard.string,
            let inputViewModel = inputViewModel,
            inputViewModel.inputHandler.value != pasteString {
            let currentValue = inputViewModel.inputHandler.value
            let currentLength = (currentValue as NSString).length
            let range = NSRange(location: 0, length: currentLength)

            _ = inputViewModel.inputHandler.didReceiveReplacement(pasteString, for: range)

            if currentValue != inputViewModel.inputHandler.value {
                textField.text = inputViewModel.inputHandler.value
                sendActions(for: .editingChanged)
                delegate?.accountInputViewDidPaste(self)
            }

            updateControlsState()
        }
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

extension AccountInputView: UITextFieldDelegate {
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
            return delegate.accountInputViewShouldReturn(self)
        } else {
            textField.resignFirstResponder()
            return true
        }
    }

    func textFieldShouldBeginEditing(_: UITextField) -> Bool {
        delegate?.accountInputViewWillStartEditing(self)
        return true
    }

    func textFieldDidEndEditing(_: UITextField, reason _: UITextField.DidEndEditingReason) {
        delegate?.accountInputViewDidEndEditing(self)
    }
}

extension AccountInputView: PasteboardHandlerDelegate {
    func didReceivePasteboardChange(notification _: Notification) {
        updateControlsState()
    }

    func didReceivePasteboardRemove(notification _: Notification) {
        updateControlsState()
    }
}
