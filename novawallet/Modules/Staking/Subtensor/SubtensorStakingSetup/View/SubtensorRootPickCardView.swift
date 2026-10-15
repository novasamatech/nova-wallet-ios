import UIKit

final class SubtensorRootPickCardView: UIView {
    let headerView = SubtensorPickCardHeaderView()
    let validatorCell = SubtensorPickValidatorCell()
    let feeCell = StackNetworkFeeCell()
    let browseButton = UIButton(type: .system)
    private let rowsView = StackTableView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12
        rowsView.fillColor = .clear
        rowsView.contentInsets = .zero
        rowsView.addArrangedSubview(validatorCell)
        rowsView.addArrangedSubview(feeCell)
        let stack = UIView.vStack(spacing: 10, [headerView, rowsView, browseButton])
        browseButton.contentHorizontalAlignment = .right
        browseButton.titleLabel?.font = .semiBoldFootnote
        browseButton.snp.makeConstraints { $0.height.equalTo(44) }
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: SubtensorSetupRootViewModel, locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        headerView.bind(viewModel: SubtensorPickCardHeaderViewModel(
            icon: model.icon, title: strings.stakingSubtensorUiStakeToRoot(), isSelectable: true
        ))
        validatorCell.titleLabel.text = strings.stakingCommonValidator()
        validatorCell.bind(validator: model.compactValidator, rate: model.compactRate, isEditable: true)
        feeCell.rowContentView.locale = locale
        feeCell.rowContentView.bind(viewModel: model.networkFee)
        browseButton.setTitle(strings.stakingSubtensorQuickSeeAll(), for: .normal)
        rowsView.updateLayout()
        SubtensorDividerStyle.apply(to: validatorCell, hasPrevious: true)
        SubtensorDividerStyle.apply(to: feeCell, hasPrevious: true)
    }
}
