import UIKit

final class SwapNetworkFeeSheetLayout: UIView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .bottomSheetTitle)
        $0.numberOfLines = 0
    }

    let detailsLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
        $0.numberOfLines = 0
    }

    let feeTypeSwitch: RoundedSegmentedControl = .create {
        $0.backgroundView.fillColor = R.color.colorSegmentedBackgroundOnBlack()!
        $0.selectionColor = R.color.colorSegmentedTabActive()!
        $0.titleFont = .regularFootnote
        $0.selectedTitleColor = R.color.colorTextPrimary()!
        $0.titleColor = R.color.colorTextSecondary()!
        $0.selectionCornerRadius = 10
    }

    let hint: IconDetailsView = .hint()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let stackView = UIView.vStack([
            titleLabel,
            detailsLabel,
            feeTypeSwitch,
            hint
        ])

        stackView.setCustomSpacing(Constants.titleDetailsOffset, after: titleLabel)
        stackView.setCustomSpacing(Constants.detailsSwitchOffset, after: detailsLabel)
        stackView.setCustomSpacing(Constants.switchHintOffset, after: feeTypeSwitch)

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(Constants.topOffset)
        }

        feeTypeSwitch.snp.makeConstraints { make in
            make.height.equalTo(Constants.controlHeight)
        }
    }
}

extension SwapNetworkFeeSheetLayout {
    enum Constants {
        static let titleDetailsOffset: CGFloat = 18
        static let detailsSwitchOffset: CGFloat = 10
        static let switchHintOffset: CGFloat = 16
        static let topOffset: CGFloat = 10
        static let bottomOffset: CGFloat = 8
        static let controlHeight: CGFloat = 40
    }
}

extension SwapNetworkFeeSheetLayout {
    func contentHeight(model: SwapNetworkFeeSheetViewModel, locale: Locale) -> CGFloat {
        let titleHeight = height(for: titleLabel, with: model.title.value(for: locale))
        let messageHeight = height(for: detailsLabel, with: model.message.value(for: locale))
        let hintHeight = height(for: hint.detailsLabel, with: model.hint.value(for: locale))

        let vOffsets = Constants.topOffset + Constants.titleDetailsOffset +
            Constants.detailsSwitchOffset + Constants.switchHintOffset + Constants.bottomOffset

        return vOffsets + titleHeight + messageHeight + Constants.controlHeight + hintHeight
    }

    private func height(for label: UILabel, with text: String) -> CGFloat {
        guard let font = label.font else {
            return 0
        }

        let width = UIScreen.main.bounds.width - UIConstants.horizontalInset * 2
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return boundingBox.height
    }
}
