import UIKit
import UIKit_iOS

final class SubtensorSlippageViewLayout: ScrollableContainerLayoutView {
    let titleLabel = UILabel(style: .boldTitle3Primary, textAlignment: .left, numberOfLines: 1)

    let slippageTitleLabel = UILabel(style: .semiboldSubhedlinePrimary, textAlignment: .left, numberOfLines: 1)

    let explanationLabel = UILabel(style: .footnoteSecondary, textAlignment: .left, numberOfLines: 0)

    let presetsControl = SubtensorSlippagePresetsControl()

    let amountInput: PercentInputView = .create {
        $0.contentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let errorLabel = UILabel(style: .caption1Negative, textAlignment: .left, numberOfLines: 0)
    private var warningView: InlineAlertView?

    override func setupStyle() {
        backgroundColor = R.color.colorBottomSheetBackground()
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins.top = Constants.topInset

        addArrangedSubview(titleLabel, spacingAfter: 16)

        addArrangedSubview(slippageTitleLabel, spacingAfter: 4)
        slippageTitleLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.slippageTitleHeight)
        }

        addArrangedSubview(explanationLabel, spacingAfter: 16)
        addArrangedSubview(presetsControl, spacingAfter: 20)

        addArrangedSubview(amountInput, spacingAfter: 8)
        amountInput.snp.makeConstraints { make in
            make.height.equalTo(Constants.inputHeight)
        }

        errorLabel.isHidden = true
        addArrangedSubview(errorLabel, spacingAfter: 8)

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    func bind(title: String, explanation: String) {
        titleLabel.apply(text: title, lineHeight: Constants.titleLineHeight)
        explanationLabel.apply(text: explanation, lineHeight: Constants.explanationLineHeight)
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        let contentHeight = stackView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        return contentHeight + Constants.actionSpacing + UIConstants.actionHeight + UIConstants.actionBottomInset
    }

    func set(error: String?) {
        errorLabel.text = error
        errorLabel.isHidden = error.isNilOrEmpty
        amountInput.apply(style: error.isNilOrEmpty ? .normal : .error)
    }

    func set(warning: String?) {
        applyWarning(
            on: &warningView,
            after: errorLabel,
            text: warning,
            spacing: 16
        )
    }
}

private extension SubtensorSlippageViewLayout {
    enum Constants {
        static let topInset: CGFloat = 8
        static let actionSpacing: CGFloat = 20
        static let titleLineHeight: CGFloat = 28
        static let slippageTitleHeight: CGFloat = 20
        static let explanationLineHeight: CGFloat = 18
        static let inputHeight: CGFloat = 52
    }
}

final class SubtensorSlippagePresetsControl: UIControl {
    private let stackView = UIView.hStack(distribution: .fillEqually, spacing: Constants.spacing, [])

    private(set) var selectedIndex: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(Constants.height)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(titles: [String]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        titles.forEach { title in
            let button = RoundedButton()
            button.applySecondaryStyle()
            button.imageWithTitleView?.title = title
            button.addTarget(self, action: #selector(actionSelect(_:)), for: .touchUpInside)

            stackView.addArrangedSubview(button)
        }

        applySelection()
    }

    func select(index: Int?) {
        selectedIndex = index

        applySelection()
    }
}

private extension SubtensorSlippagePresetsControl {
    enum Constants {
        static let height: CGFloat = 36
        static let spacing: CGFloat = 8
    }

    @objc func actionSelect(_ sender: RoundedButton) {
        guard let index = stackView.arrangedSubviews.firstIndex(where: { $0 === sender }) else {
            return
        }

        select(index: index)
        sendActions(for: .valueChanged)
    }

    func applySelection() {
        for (index, view) in stackView.arrangedSubviews.enumerated() {
            guard let button = view as? RoundedButton else {
                continue
            }

            let isSelected = index == selectedIndex
            let fillColor = isSelected ? R.color.colorButtonBackgroundPrimary()! : R.color.colorChipsBackground()!
            let titleColor = isSelected ? R.color.colorTextPrimary()! : R.color.colorTextSecondary()!

            button.roundedBackgroundView?.fillColor = fillColor
            button.roundedBackgroundView?.highlightedFillColor = fillColor
            button.imageWithTitleView?.titleColor = titleColor
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }
}
