import UIKit
import SoraUI

final class SwapSymbolView: GenericPairValueView<GenericPairValueView<IconDetailsView, FlexibleSpaceView>, IconDetailsView> {
    var symbolLabel: UILabel { fView.fView.detailsLabel }
    var disclosureImageView: UIImageView { fView.fView.imageView }
    var hubNameView: UILabel { sView.detailsLabel }
    var hubImageView: UIImageView { sView.imageView }

    private var imageViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        fView.makeHorizontal()
        fView.fView.spacing = 0
        fView.fView.iconWidth = 20
        fView.fView.mode = .detailsIcon

        sView.spacing = 8
        sView.iconWidth = 16
        sView.mode = .iconDetails

        spacing = 4
        makeVertical()

        symbolLabel.apply(style: .semiboldBodyPrimary)
        hubNameView.apply(style: .footnoteSecondary)
    }

    override var intrinsicContentSize: CGSize {
        let symbolWidth = symbolLabel.intrinsicContentSize.width + fView.fView.iconWidth
        let hubWidth = sView.iconWidth + sView.spacing + hubNameView.intrinsicContentSize.width
        let width: CGFloat = max(symbolWidth, hubWidth)
        let symbolHeight = max(symbolLabel.intrinsicContentSize.height, fView.fView.iconWidth)
        let hubHeight = max(hubNameView.intrinsicContentSize.height, sView.iconWidth)
        let height = symbolHeight + spacing + hubHeight
        return .init(
            width: width,
            height: height
        )
    }

    func bind(symbol: String, network: String, icon: ImageViewModelProtocol?) {
        symbolLabel.text = symbol
        imageViewModel?.cancel(on: hubImageView)
        imageViewModel = icon
        icon?.loadImage(
            on: hubImageView,
            targetSize: .init(
                width: sView.iconWidth,
                height: sView.iconWidth
            ),
            animated: true
        )
        sView.hidesIcon = icon == nil
        hubNameView.text = network
        disclosureImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        invalidateIntrinsicContentSize()
    }
}

final class SwapAmountInputView: BackgroundedContentControl {
    var iconView: AssetIconView { lazyIconViewOrCreateIfNeeded() }
    private var lazyIconView: AssetIconView?

    let symbolHubMultiValueView = SwapSymbolView()
    var iconViewContentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4) {
        didSet {
            iconView.contentInsets = iconViewContentInsets
            setNeedsLayout()
        }
    }

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

    var roundedBackgroundView: RoundedView? {
        backgroundView as? RoundedView
    }

    var horizontalSpacing: CGFloat = 8 {
        didSet {
            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16 {
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
            symbolHubMultiValueView.intrinsicContentSize.height
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

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutContent()
    }

    private func layoutContent() {
        let availableWidth = bounds.width - contentInsets.left - contentInsets.right
        let symbolSize = symbolHubMultiValueView.intrinsicContentSize
        if let iconView = lazyIconView {
            iconView.frame = CGRect(
                x: bounds.minX + contentInsets.left,
                y: bounds.midY - iconRadius,
                width: 2.0 * iconRadius,
                height: 2.0 * iconRadius
            )

            symbolHubMultiValueView.frame = CGRect(
                x: iconView.frame.maxX + horizontalSpacing,
                y: bounds.midY - symbolSize.height / 2.0,
                width: min(availableWidth, symbolSize.width),
                height: symbolSize.height
            )
        } else {
            symbolHubMultiValueView.frame = CGRect(
                x: contentInsets.left,
                y: bounds.midY - symbolSize.height / 2.0,
                width: min(availableWidth, symbolSize.width),
                height: symbolSize.height
            )
        }

        let estimatedFieldWidth = bounds.maxX - contentInsets.right
            - symbolHubMultiValueView.frame.maxX - horizontalSpacing
        let fieldWidth = max(estimatedFieldWidth, 0.0)

        let hasPriceLabel = !priceLabel.text.isNilOrEmpty
        let fieldHeight = textField.intrinsicContentSize.height

        let textFieldY: CGFloat

        if hasPriceLabel {
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
        configureLocalHandlers()
        configureTextFieldHandlers()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let roundedView = RoundedView()
            roundedView.apply(style: .strokeOnEditing)
            roundedView.isUserInteractionEnabled = false
            backgroundView = roundedView
        }
    }

    private func configureLocalHandlers() {
        addTarget(self, action: #selector(actionTouchUpInside), for: .touchUpInside)
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

        contentView?.addSubview(symbolHubMultiValueView)
        contentView?.addSubview(priceLabel)
        addSubview(textField)

        contentInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 16)
    }

    private func lazyIconViewOrCreateIfNeeded() -> AssetIconView {
        if let iconView = lazyIconView {
            return iconView
        }

        let size = 2 * iconRadius
        let initFrame = CGRect(origin: .zero, size: .init(width: size, height: size))
        let imageView = AssetIconView(frame: initFrame)
        imageView.contentInsets = iconViewContentInsets
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
        roundedBackgroundView?.strokeWidth = textField.isFirstResponder ? 0.5 : 0.0
    }

    @objc private func actionTouchUpInside() {
        if !textField.isHidden {
            textField.becomeFirstResponder()
        }
    }
}

extension SwapAmountInputView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        inputViewModel?.didReceiveReplacement(string, for: range) ?? false
    }
}

extension SwapAmountInputView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        textField.text = inputViewModel?.displayAmount

        sendActions(for: .editingChanged)
    }
}

extension SwapAmountInputView {
    func bind(assetViewModel: SwapsAssetViewModel) {
        let width = 2 * iconRadius - iconView.contentInsets.left - iconView.contentInsets.right
        let height = 2 * iconRadius - iconView.contentInsets.top - iconView.contentInsets.bottom
        iconViewContentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        let size = CGSize(width: width, height: height)
        iconView.bind(viewModel: assetViewModel.imageViewModel, size: size)

        symbolHubMultiValueView.bind(
            symbol: assetViewModel.symbol,
            network: assetViewModel.hub.name,
            icon: assetViewModel.hub.icon
        )
        setNeedsLayout()
    }

    func bind(emptyViewModel: EmptySwapsAssetViewModel) {
        let size = CGSize(width: 2 * iconRadius, height: 2 * iconRadius)
        iconView.bind(viewModel: emptyViewModel.imageViewModel, size: size)
        iconViewContentInsets = .zero
        symbolHubMultiValueView.bind(
            symbol: emptyViewModel.title,
            network: emptyViewModel.subtitle,
            icon: nil
        )
        textField.isHidden = true
        setNeedsLayout()
    }

    func bind(inputViewModel: AmountInputViewModelProtocol) {
        textField.isHidden = false
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

struct SwapsAssetViewModel {
    let symbol: String
    let imageViewModel: ImageViewModelProtocol?
    let hub: NetworkViewModel
}

struct EmptySwapsAssetViewModel {
    let imageViewModel: ImageViewModelProtocol?
    let title: String
    let subtitle: String
}
