import UIKit
import UIKit_iOS

final class SwapAmountInputView: RoundedView {
    let assetControl: SwapAssetControl = .create {
        $0.iconRadius = Constants.iconRadius
        $0.horizontalSpacing = Constants.iconSpacing
    }

    let textInputView = SwapAmountInput()

    private var style: Style = .normal

    var contentInsets = UIEdgeInsets(top: 12, left: 13, bottom: 12, right: 17) {
        didSet {
            setNeedsLayout()
        }
    }

    var horizontalSpacing: CGFloat = 12 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.height)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        assetControl.frame = swapAssetControlFrame(bounds: bounds)
        textInputView.frame = inputViewFrame(
            bounds: bounds,
            assetControlFrame: assetControl.frame
        )
    }

    private func swapAssetControlFrame(bounds: CGRect) -> CGRect {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let swapAssetControlSize = assetControl.intrinsicContentSize

        let width = textInputView.isHidden ? availableWidth :
            min(min(availableWidth, swapAssetControlSize.width), Constants.assetMaxWidthRatio * availableWidth)

        return CGRect(
            x: contentInsets.left,
            y: bounds.midY - swapAssetControlSize.height / 2.0,
            width: width,
            height: swapAssetControlSize.height
        )
    }

    private func inputViewFrame(
        bounds: CGRect,
        assetControlFrame: CGRect
    ) -> CGRect {
        let estimatedInputViewWidth = bounds.width - contentInsets.left -
            assetControlFrame.width - contentInsets.right - horizontalSpacing

        let inputWidth = max(estimatedInputViewWidth, 0)

        return CGRect(
            x: assetControlFrame.maxX + horizontalSpacing,
            y: contentInsets.top,
            width: inputWidth,
            height: max(bounds.height - contentInsets.top - contentInsets.bottom, 0)
        )
    }

    // MARK: Configure

    override func configure() {
        super.configure()

        backgroundColor = UIColor.clear
        apply(style: .strokeOnEditing)

        configureContent()
        configureInputViewHandlers()
        updateFocusState()
    }

    private func configureContent() {
        addSubview(assetControl)
        addSubview(textInputView)

        assetControl.contentInsets = .zero
        assetControl.iconView.contentInsets = Constants.iconInsets
        textInputView.contentInsets = .zero
    }

    private func configureInputViewHandlers() {
        textInputView.textField.addTarget(
            self,
            action: #selector(actionEditingDidBeginEnd),
            for: .editingDidBegin
        )

        textInputView.textField.addTarget(
            self,
            action: #selector(actionEditingDidBeginEnd),
            for: .editingDidEnd
        )
    }

    private func updateFocusState() {
        switch style {
        case .error:
            strokeWidth = Constants.borderWidth
        case .normal:
            strokeWidth = textInputView.textField.isFirstResponder ? Constants.borderWidth : 0.0
        }
    }

    @objc private func actionEditingDidBeginEnd() {
        if textInputView.textField.isFirstResponder {
            textInputView.setValueMasked(false)
        }

        updateFocusState()
    }
}

extension SwapAmountInputView {
    var isAmountFocused: Bool {
        textInputView.textField.isFirstResponder
    }

    func bind(assetViewModel: SwapsAssetViewModel) {
        textInputView.isHidden = false
        assetControl.bind(assetViewModel: assetViewModel)
        setNeedsLayout()
    }

    func bind(emptyViewModel: EmptySwapsAssetViewModel) {
        textInputView.isHidden = true
        textInputView.textField.resignFirstResponder()
        assetControl.bind(emptyViewModel: emptyViewModel)
        setNeedsLayout()
    }

    func bind(inputViewModel: AmountInputViewModelProtocol) {
        textInputView.isHidden = false
        textInputView.bind(inputViewModel: inputViewModel)
    }

    func bind(priceViewModel: String?) {
        textInputView.bind(priceViewModel: priceViewModel)
        setNeedsLayout()
    }

    func setLoading(_ loading: Bool) {
        textInputView.setLoading(loading && !textInputView.isHidden)
    }

    func setValueMasked(_ masked: Bool) {
        textInputView.setValueMasked(masked && !isAmountFocused)
    }

    func set(focused: Bool) {
        guard !textInputView.isHidden else {
            return
        }
        if focused {
            textInputView.textField.becomeFirstResponder()
        } else {
            textInputView.textField.resignFirstResponder()
        }
    }
}

extension SwapAmountInputView {
    enum Style {
        case normal
        case error
    }

    func applyInput(style: Style) {
        switch style {
        case .error:
            apply(style: .strokeOnError)
            textInputView.textField.textColor = R.color.colorTextNegative()
            textInputView.textField.tintColor = R.color.colorTextNegative()
        case .normal:
            apply(style: .strokeOnEditing)
            textInputView.textField.textColor = R.color.colorTextPrimary()
            textInputView.textField.tintColor = R.color.colorTextPrimary()
        }
        self.style = style

        updateFocusState()
    }
}

extension SwapAmountInputView {
    enum Constants {
        static let height: CGFloat = 72
        static let iconRadius: CGFloat = 21
        static let iconSpacing: CGFloat = 12
        static let iconInsets = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        static let borderWidth: CGFloat = 1
        static let assetMaxWidthRatio: CGFloat = 0.7
    }
}
