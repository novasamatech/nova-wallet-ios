import UIKit
import UIKit_iOS
import Foundation_iOS

final class MultilineTextInputView: BackgroundedContentControl {
    let textView: UITextView = {
        let textView = UITextView()
        textView.font = .regularSubheadline
        textView.textColor = R.color.colorTextPrimary()
        textView.tintColor = R.color.colorTextPrimary()
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero

        textView.keyboardType = .default
        textView.returnKeyType = .done
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false

        return textView
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
        view.alignment = .top
        return view
    }()

    let rightFieldSpacing: CGFloat = 8.0

    weak var delegate: MultilineTextInputViewDelegate?

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    private(set) var inputViewModel: InputViewModelProtocol?

    private var placeholderTextView: UITextView = {
        let textView = UITextView()
        textView.font = .regularSubheadline
        textView.textColor = R.color.colorTextSecondary()
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.isEditable = false
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
        textView.isScrollEnabled = false
        return textView
    }()

    private var minHeight: CGFloat = 48.0
    private var maxHeight: CGFloat = 250.0

    var completed: Bool {
        if let inputViewModel = inputViewModel {
            return inputViewModel.inputHandler.completed
        } else {
            return false
        }
    }

    var hasText: Bool {
        if let text = textView.text, !text.isEmpty {
            return true
        } else {
            return false
        }
    }

    override var intrinsicContentSize: CGSize {
        let contentWidth = bounds.width
            - (contentInsets.left + contentInsets.right)
            - stackView.bounds.width
            - rightFieldSpacing
        let contentSize = CGSize(
            width: contentWidth,
            height: .greatestFiniteMagnitude
        )
        let textSize = textView.sizeThatFits(contentSize)
        let height = max(minHeight, min(maxHeight, textSize.height + contentInsets.top + contentInsets.bottom))

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    func bind(inputViewModel: InputViewModelProtocol) {
        if textView.text != inputViewModel.inputHandler.value {
            textView.text = inputViewModel.inputHandler.value
        }

        if !inputViewModel.placeholder.isEmpty {
            placeholderTextView.text = inputViewModel.placeholder
        }

        textView.isEditable = inputViewModel.inputHandler.enabled
        textView.isUserInteractionEnabled = inputViewModel.inputHandler.enabled

        self.inputViewModel = inputViewModel

        updateControlsState()
        updatePlaceholderVisibility()
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
            y: contentInsets.top,
            width: actionsWidth,
            height: buttonHeight
        )

        let fieldWidth: CGFloat

        if actionsWidth > 0 {
            fieldWidth = max(
                stackView.frame.minX - contentInsets.left - rightFieldSpacing,
                0
            )
        } else {
            fieldWidth = max(bounds.width - contentInsets.left - contentInsets.right, 0)
        }

        let fieldHeight = max(bounds.height - contentInsets.top - contentInsets.bottom, 0)

        textView.frame = CGRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: fieldWidth,
            height: fieldHeight
        )

        placeholderTextView.frame = textView.frame
    }

    func handleTextChangeWithResize() {
        updateControlsState()
        updatePlaceholderVisibility()

        invalidateIntrinsicContentSize()
        setNeedsLayout()

        sendActions(for: .editingChanged)
    }

    // MARK: Configure

    func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        configureLocalHandlers()
        configureTextViewHandlers()
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

        addSubview(placeholderTextView)
        addSubview(textView)

        stackView.addArrangedSubview(clearButton)
        addSubview(stackView)

        contentInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
    }

    private func configureTextViewHandlers() {
        textView.delegate = self
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
        if shouldUseClearButton, hasText, textView.isEditable {
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

    private func updatePlaceholderVisibility() {
        placeholderTextView.isHidden = hasText
    }

    // MARK: Action

    @objc private func actionEditingBeginEnd() {
        roundedBackgroundView?.strokeWidth = textView.isFirstResponder ? 0.5 : 0
        updateControlsState()
    }

    @objc private func actionTouchUpInside() {
        textView.becomeFirstResponder()
    }

    @objc func actionClear() {
        guard hasText else {
            return
        }

        textView.text = ""
        inputViewModel?.inputHandler.changeValue(to: "")

        updateControlsState()
        updatePlaceholderVisibility()
        invalidateIntrinsicContentSize()

        sendActions(for: .editingChanged)
    }
}

extension MultilineTextInputView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Handle return key
        if text == "\n" {
            if let delegate = delegate {
                return !delegate.textInputViewShouldReturn(self)
            } else {
                textView.resignFirstResponder()
                return false
            }
        }

        guard let inputViewModel else {
            return true
        }

        let shouldApply = inputViewModel.inputHandler.didReceiveReplacement(text, for: range)

        if !shouldApply, textView.text != inputViewModel.inputHandler.value {
            textView.text = inputViewModel.inputHandler.value
        }

        // Paste assumption
        if text.count > 1 {
            // We want to update layout after the text view has processed the change
            DispatchQueue.main.async {
                self.handleTextChangeWithResize()
            }
        }

        return shouldApply
    }

    func textViewDidChange(_ textView: UITextView) {
        if inputViewModel?.inputHandler.value != textView.text {
            inputViewModel?.inputHandler.changeValue(to: textView.text)
        }

        handleTextChangeWithResize()
    }

    func textViewDidBeginEditing(_: UITextView) {
        delegate?.textInputViewWillStartEditing(self)
        actionEditingBeginEnd()
    }

    func textViewDidEndEditing(_: UITextView) {
        actionEditingBeginEnd()
    }
}
