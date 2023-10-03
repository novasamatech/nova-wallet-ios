import SoraUI

final class SwapAmountInputView: RoundedView {
    let swapAssetControl = SwapAssetControl()
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
        let leftContentHeight = swapAssetControl.intrinsicContentSize.height
        let rightContentHeight = textInputView.intrinsicContentSize.height

        let contentHeight = max(leftContentHeight, rightContentHeight)

        let height = contentInsets.top + contentHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        layoutContent()
    }

    private func layoutContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let swapAssetControlSize = swapAssetControl.intrinsicContentSize

        guard !textInputView.isHidden else {
            swapAssetControl.frame = CGRect(
                x: contentInsets.left,
                y: bounds.midY - swapAssetControlSize.height / 2.0,
                width: availableWidth,
                height: swapAssetControlSize.height
            )
            return
        }
        swapAssetControl.frame = CGRect(
            x: contentInsets.left,
            y: bounds.midY - swapAssetControlSize.height / 2.0,
            width: min(min(availableWidth, swapAssetControlSize.width), 0.7 * availableWidth),
            height: swapAssetControlSize.height
        )

        let estimatedInputViewWidth = bounds.maxX - contentInsets.right
            - swapAssetControl.frame.maxX - horizontalSpacing
        let inputWidth = max(estimatedInputViewWidth, 0)
        let inputSize = textInputView.intrinsicContentSize

        textInputView.frame = CGRect(
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

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        configureInputViewHandlers()
    }

    private func configureBackgroundViewIfNeeded() {
        apply(style: .strokeOnEditing)
    }

    private func configureContentViewIfNeeded() {
        addSubview(swapAssetControl)
        addSubview(textInputView)

        swapAssetControl.contentInsets = .zero
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

    // MARK: Action

    @objc private func actionEditingDidBeginEnd() {
        strokeWidth = textInputView.isFirstResponder ? 0.5 : 0.0
    }
}

extension SwapAmountInputView {
    func bind(assetViewModel: SwapsAssetViewModel) {
        swapAssetControl.bind(assetViewModel: assetViewModel)
        swapAssetControl.invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func bind(emptyViewModel: EmptySwapsAssetViewModel) {
        swapAssetControl.bind(emptyViewModel: emptyViewModel)
        textInputView.isHidden = true
        swapAssetControl.invalidateIntrinsicContentSize()
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
