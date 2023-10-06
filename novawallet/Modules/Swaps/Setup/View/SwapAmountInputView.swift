import SoraUI

final class SwapAmountInputView: RoundedView {
    let assetControl = SwapAssetControl()
    let textInputView = SwapAmountInput()

    var contentInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 16) {
        didSet {
            setNeedsLayout()
        }
    }

    var horizontalSpacing: CGFloat = 8 {
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
        let leftContentHeight = assetControl.intrinsicContentSize.height
        let rightContentHeight = textInputView.intrinsicContentSize.height

        let contentHeight = max(leftContentHeight, rightContentHeight)

        let height = contentInsets.top + contentHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
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
            min(min(availableWidth, swapAssetControlSize.width), 0.7 * availableWidth)

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
        let estimatedInputViewWidth = bounds.maxX - contentInsets.right - assetControlFrame.maxX - horizontalSpacing
        let inputWidth = max(estimatedInputViewWidth, 0)
        let inputSize = textInputView.intrinsicContentSize

        return CGRect(
            x: bounds.maxX - contentInsets.right - inputWidth,
            y: bounds.midY - inputSize.height / 2.0,
            width: inputWidth,
            height: inputSize.height
        )
    }

    // MARK: Configure

    override func configure() {
        super.configure()

        backgroundColor = UIColor.clear
        apply(style: .strokeOnEditing)

        configureContent()
        configureInputViewHandlers()
    }

    private func configureContent() {
        addSubview(assetControl)
        addSubview(textInputView)

        assetControl.contentInsets = .zero
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

    @objc private func actionEditingDidBeginEnd() {
        strokeWidth = textInputView.textField.isFirstResponder ? 0.5 : 0.0
    }
}

extension SwapAmountInputView {
    func bind(assetViewModel: SwapsAssetViewModel) {
        assetControl.bind(assetViewModel: assetViewModel)
        setNeedsLayout()
    }

    func bind(emptyViewModel: EmptySwapsAssetViewModel) {
        assetControl.bind(emptyViewModel: emptyViewModel)
        textInputView.isHidden = true
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
}
