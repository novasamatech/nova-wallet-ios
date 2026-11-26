import UIKit
import UIKit_iOS

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

    let placeholderLabel: UILabel = .create {
        $0.font = .title2
        $0.textColor = R.color.colorHintText()
        $0.textAlignment = .right
        $0.text = "0"
        $0.isHidden = true
    }

    var skeletonView: SkrullableView?

    private(set) var isLoading: Bool = false

    override var intrinsicContentSize: CGSize {
        let contentHeight = Constants.amountHeight + Constants.spacing + Constants.priceHeight

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

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    var isValueMasked: Bool {
        !placeholderLabel.isHidden
    }

    func setValueMasked(_ masked: Bool) {
        guard masked != isValueMasked else {
            return
        }

        placeholderLabel.isHidden = !masked
        updateValueVisibility()
    }

    func setLoading(_ loading: Bool) {
        guard loading != isLoading else {
            return
        }

        if loading {
            startLoadingIfNeeded()
        } else {
            stopLoadingIfNeeded()
        }
    }
}

// MARK: Private

private extension SwapAmountInput {
    func updateValueVisibility() {
        let alpha: CGFloat = isValueMasked || isLoading ? 0 : 1

        textField.alpha = alpha
        priceLabel.alpha = alpha
    }

    func layoutContent() {
        let availableWidth = max(bounds.width - contentInsets.left - contentInsets.right, 0)

        let contentHeight = priceLabel.text.isNilOrEmpty
            ? Constants.amountHeight
            : Constants.amountHeight + Constants.spacing + Constants.priceHeight

        textField.frame = CGRect(
            x: bounds.maxX - contentInsets.right - availableWidth,
            y: bounds.midY - contentHeight / 2,
            width: availableWidth,
            height: Constants.amountHeight
        )

        priceLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - availableWidth,
            y: textField.frame.maxY + Constants.spacing,
            width: availableWidth,
            height: Constants.priceHeight
        )

        placeholderLabel.frame = CGRect(
            x: textField.frame.minX,
            y: bounds.midY - Constants.amountHeight / 2,
            width: availableWidth,
            height: Constants.amountHeight
        )
    }

    func configure() {
        backgroundColor = UIColor.clear

        configureContentViewIfNeeded()
        configureLocalHandlers()
    }

    func configureLocalHandlers() {
        addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)
        textField.delegate = self
    }

    func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        contentView?.addSubview(priceLabel)
        contentView?.addSubview(textField)
        contentView?.addSubview(placeholderLabel)
    }

    @objc func actionTouchUpInside() {
        textField.becomeFirstResponder()
    }
}

// MARK: SkeletonableView

extension SwapAmountInput: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [textField, priceLabel]
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let amountOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - Constants.amountSkeletonSize.width,
            y: spaceSize.height / 2 - Constants.skeletonsHeight / 2
        )

        let priceOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - Constants.priceSkeletonSize.width,
            y: amountOffset.y + Constants.amountSkeletonSize.height + Constants.skeletonsSpacing
        )

        return [amountOffset, priceOffset].enumerated().map { index, offset in
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: index == 0 ? Constants.amountSkeletonSize : Constants.priceSkeletonSize
            )
        }
    }

    func didStartSkeleton() {
        isLoading = true
        updateValueVisibility()
    }

    func didStopSkeleton() {
        isLoading = false
        updateValueVisibility()
    }
}

// MARK: UITextFieldDelegate

extension SwapAmountInput: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

// MARK: AmountInputViewModelObserver

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

private extension SwapAmountInput {
    enum Constants {
        static let amountHeight: CGFloat = 28
        static let priceHeight: CGFloat = 18
        static let spacing: CGFloat = 2
        static let amountSkeletonSize = CGSize(width: 96, height: 20)
        static let priceSkeletonSize = CGSize(width: 64, height: 12)
        static let skeletonsSpacing: CGFloat = 8

        static var skeletonsHeight: CGFloat {
            amountSkeletonSize.height + skeletonsSpacing + priceSkeletonSize.height
        }
    }
}
