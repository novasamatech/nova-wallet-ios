import UIKit
import SoraUI
import CommonWallet

class NewAmountInputView: BackgroundedContentControl {
    let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTransparentText()
        label.textAlignment = .right
        return label
    }()

    let symbolLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldBody
        label.textColor = R.color.colorWhite()
        return label
    }()

    let textField: UITextField = {
        let textField = UITextField()
        textField.font = .title2
        textField.textColor = R.color.colorWhite()
        textField.tintColor = R.color.colorWhite()
        textField.textAlignment = .right

        textField.attributedPlaceholder = NSAttributedString(
            string: "0",
            attributes: [
                .foregroundColor: R.color.colorWhite()!.withAlphaComponent(0.5),
                .font: UIFont.title2
            ]
        )

        textField.keyboardType = .decimalPad

        return textField
    }()

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    var iconView: AssetIconView { lazyIconViewOrCreateIfNeeded() }
    private var lazyIconView: AssetIconView?

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16.0 {
        didSet {
            lazyIconView?.backgroundView.cornerRadius = iconRadius

            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let rightContentHeight = max(
            textField.intrinsicContentSize.height,
            priceLabel.intrinsicContentSize.height
        )

        let leftContentHeight = max(
            lazyIconView?.intrinsicContentSize.height ?? 0.0,
            symbolLabel.intrinsicContentSize.height
        )

        let contentHeight = max(leftContentHeight, rightContentHeight)

        let height = contentInsets.top + contentHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    private(set) var inputViewModel: AmountInputViewModelProtocol?

    var completed: Bool {
        if let inputViewModel = inputViewModel {
            return inputViewModel.isValid
        } else {
            return false
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    func bind(assetViewModel: AssetViewModel) {
        let width = 2 * iconRadius - iconView.contentInsets.left - iconView.contentInsets.right
        let height = 2 * iconRadius - iconView.contentInsets.top - iconView.contentInsets.bottom

        let size = CGSize(width: width, height: height)
        iconView.bind(viewModel: assetViewModel.imageViewModel, size: size)

        symbolLabel.text = assetViewModel.symbol

        setNeedsLayout()
    }

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

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutContent()
    }

    private func layoutContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let symbolSize = symbolLabel.intrinsicContentSize
        if let iconView = lazyIconView {
            iconView.frame = CGRect(
                x: bounds.minX + contentInsets.left,
                y: bounds.midY - iconRadius,
                width: 2.0 * iconRadius,
                height: 2.0 * iconRadius
            )

            symbolLabel.frame = CGRect(
                x: iconView.frame.maxX + horizontalSpacing,
                y: bounds.midY - symbolSize.height / 2.0,
                width: min(availableWidth, symbolSize.width),
                height: symbolSize.height
            )
        } else {
            symbolLabel.frame = CGRect(
                x: contentInsets.left,
                y: bounds.midY - symbolSize.height / 2.0,
                width: min(availableWidth, symbolSize.width),
                height: symbolSize.height
            )
        }

        let estimatedFieldWidth = bounds.maxX - contentInsets.right
            - symbolLabel.frame.maxX - horizontalSpacing
        let fieldWidth = max(estimatedFieldWidth, 0.0)

        let hasPriceLable = !(priceLabel.text ?? "").isEmpty

        let fieldHeight = textField.intrinsicContentSize.height

        let textFieldY: CGFloat

        if hasPriceLable {
            let fieldBaselineOffset = 4.0
            textFieldY = bounds.midY - fieldHeight + fieldBaselineOffset
        } else {
            textFieldY = bounds.midY - fieldHeight / 2.0
        }

        textField.frame = CGRect(
            x: bounds.maxX - contentInsets.right - fieldWidth,
            y: textFieldY,
            width: fieldWidth,
            height: fieldHeight
        )

        priceLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - fieldWidth,
            y: textField.frame.maxY,
            width: fieldWidth,
            height: priceLabel.intrinsicContentSize.height
        )
    }

    // MARK: Configure

    private func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        configureTextFieldHandlers()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let roundedView = RoundedView()
            roundedView.isUserInteractionEnabled = false
            roundedView.shadowOpacity = 0.0
            roundedView.strokeColor = R.color.colorAccent()!
            roundedView.fillColor = R.color.colorWhite8()!
            roundedView.highlightedFillColor = R.color.colorWhite8()!
            roundedView.strokeWidth = 0.0
            roundedView.cornerRadius = 12.0

            backgroundView = roundedView
        }
    }

    private func configureTextFieldHandlers() {
        textField.delegate = self

        textField.addTarget(
            self,
            action: #selector(actionEditingDidBeginEnd),
            for: .editingDidBegin
        )

        textField.addTarget(
            self,
            action: #selector(actionEditingDidBeginEnd),
            for: .editingDidEnd
        )
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        contentView?.addSubview(symbolLabel)
        contentView?.addSubview(priceLabel)
        addSubview(textField)

        contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 16.0)
    }

    private func lazyIconViewOrCreateIfNeeded() -> AssetIconView {
        if let iconView = lazyIconView {
            return iconView
        }

        let initFrame = CGRect(x: 0.0, y: 0.0, width: 2 * iconRadius, height: 2 * iconRadius)
        let imageView = AssetIconView(frame: initFrame)
        imageView.contentInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        imageView.backgroundView.cornerRadius = iconRadius
        contentView?.addSubview(imageView)

        lazyIconView = imageView

        if superview != nil {
            setNeedsLayout()
        }

        return imageView
    }

    // MARK: Action

    @objc private func actionEditingDidBeginEnd() {
        if textField.isFirstResponder {
            roundedBackgroundView?.strokeWidth = 0.5
        } else {
            roundedBackgroundView?.strokeWidth = 0.0
        }
    }
}

extension NewAmountInputView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension NewAmountInputView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        textField.text = inputViewModel?.displayAmount

        sendActions(for: .editingChanged)
    }
}
