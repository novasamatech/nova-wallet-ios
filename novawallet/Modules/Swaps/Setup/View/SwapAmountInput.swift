import SoraUI

final class SwapAmountInput: BackgroundedContentControl {
    let textField: UITextField = .create {
        $0.font = .title2
        $0.textColor = R.color.colorTextPrimary()
        $0.tintColor = R.color.colorTextPrimary()
        $0.textAlignment = .right
        $0.attributedPlaceholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: R.color.colorHintText()!,
                .font: UIFont.title2
            ]
        )
        $0.keyboardType = .decimalPad
    }

    let priceLabel = UILabel(
        style: .footnoteSecondary,
        textAlignment: .right,
        numberOfLines: 1
    )

    let spacing: CGFloat = 4

    override var intrinsicContentSize: CGSize {
        let contentHeight = textField.intrinsicContentSize.height + spacing + priceLabel.intrinsicContentSize.height

        let height = contentInsets.top + contentHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    private(set) var inputViewModel: AmountInputViewModelProtocol?

    var completed: Bool {
        inputViewModel?.isValid == true
    }

    var hasValidNumber: Bool {
        inputViewModel?.decimalAmount != nil
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutContent()
    }

    private func layoutContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let textFieldWidth = max(availableWidth, 0)

        let textFieldHeight: CGFloat = textField.intrinsicContentSize.height
        let textFieldY: CGFloat

        if !priceLabel.text.isNilOrEmpty {
            textFieldY = bounds.midY - textFieldHeight + spacing
        } else {
            textFieldY = bounds.midY - textFieldHeight / 2
        }

        textField.frame = CGRect(
            x: bounds.maxX - contentInsets.right - textFieldWidth,
            y: textFieldY,
            width: textFieldWidth,
            height: textFieldHeight
        )

        priceLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - textFieldWidth,
            y: textField.frame.maxY,
            width: textFieldWidth,
            height: priceLabel.intrinsicContentSize.height
        )
    }

    private func configure() {
        backgroundColor = UIColor.clear

        configureContentViewIfNeeded()
        configureLocalHandlers()
    }

    private func configureLocalHandlers() {
        addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)
        textField.delegate = self
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        contentView?.addSubview(priceLabel)
        contentView?.addSubview(textField)
    }

    @objc private func actionTouchUpInside() {
        textField.becomeFirstResponder()
    }
}

extension SwapAmountInput: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension SwapAmountInput: AmountInputViewModelObserver {
    func amountInputDidChange() {
        textField.text = inputViewModel?.displayAmount

        if textField.isEditing {
            sendActions(for: .editingChanged)
        }
    }
}

extension SwapAmountInput {
    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)
        inputViewModel.observable.add(observer: self)

        self.inputViewModel = inputViewModel
        textField.text = inputViewModel.displayAmount
    }

    func bind(priceViewModel: String?) {
        priceLabel.text = priceViewModel

        setNeedsLayout()
    }
}
