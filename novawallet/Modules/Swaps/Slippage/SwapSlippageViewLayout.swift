import UIKit
import UIKit_iOS

final class SwapSlippageViewLayout: ScrollableContainerLayoutView {
    let slippageButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = R.image.iconInfoFilled()
        $0.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        $0.imageWithTitleView?.titleFont = .semiBoldBody
        $0.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        $0.imageWithTitleView?.layoutType = .horizontalLabelFirst
        $0.contentInsets = .init(top: 0, left: 0, bottom: 12, right: 0)
    }

    let amountInput = PercentInputView()

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let errorLabel = UILabel(style: .caption1Negative, textAlignment: .left, numberOfLines: 0)
    private var warningView: InlineAlertView?

    let titleLabel = UILabel(style: .boldTitle3Primary, textAlignment: .left, numberOfLines: 1)

    let explanationLabel = UILabel(style: .footnoteSecondary, textAlignment: .left, numberOfLines: 0)

    let presetsControl = SwapSlippagePresetsControl()

    override func setupLayout() {
        super.setupLayout()
        let title = UIView.hStack([
            slippageButton,
            FlexibleSpaceView()
        ])
        addArrangedSubview(title)
        slippageButton.setContentHuggingPriority(.low, for: .horizontal)
        addArrangedSubview(amountInput, spacingAfter: 8)

        amountInput.snp.makeConstraints {
            $0.height.equalTo(48)
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

    func applySheetLayout() {
        backgroundColor = R.color.colorBottomSheetBackground()

        slippageButton.imageWithTitleView?.iconImage = nil
        slippageButton.isUserInteractionEnabled = false
        slippageButton.contentInsets = .zero

        let slippageTitleView = slippageButton.superview ?? slippageButton

        insertArrangedSubview(titleLabel, before: slippageTitleView, spacingAfter: 16)
        stackView.setCustomSpacing(4, after: slippageTitleView)
        insertArrangedSubview(explanationLabel, after: slippageTitleView, spacingAfter: 16)
        insertArrangedSubview(presetsControl, after: explanationLabel, spacingAfter: 20)

        amountInput.contentInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        amountInput.snp.updateConstraints { make in
            make.height.equalTo(52)
        }
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

final class SwapSlippagePresetsControl: UIControl {
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

private extension SwapSlippagePresetsControl {
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
