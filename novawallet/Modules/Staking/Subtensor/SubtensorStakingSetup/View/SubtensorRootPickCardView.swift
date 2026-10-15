import UIKit

final class SubtensorRootPickCardView: UIView {
    let headerView = SubtensorPickCardHeaderView()
    let validatorCell = SubtensorPickValidatorCell()
    let feeCell = StackNetworkFeeCell()
    let browseView = SubtensorBrowseLinkView()
    private let rowsView = StackTableView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12
        rowsView.fillColor = .clear
        rowsView.contentInsets = .zero
        rowsView.addArrangedSubview(validatorCell)
        rowsView.addArrangedSubview(feeCell)
        let stack = UIView.vStack(spacing: 12, [headerView, rowsView, browseView])
        stack.setCustomSpacing(10, after: rowsView)
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ model: SubtensorSetupRootViewModel, locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        headerView.bind(viewModel: SubtensorPickCardHeaderViewModel(
            icon: model.icon, title: strings.stakingSubtensorUiStakeToRoot(), isSelectable: false
        ))
        validatorCell.titleLabel.text = strings.stakingCommonValidator()
        validatorCell.bind(validator: model.compactValidator, rate: model.compactRate, isEditable: true)
        feeCell.rowContentView.locale = locale
        feeCell.rowContentView.bind(viewModel: model.networkFee)
        browseView.bind(title: strings.stakingSubtensorQuickSeeAll())
        rowsView.updateLayout()
        SubtensorDividerStyle.apply(to: validatorCell, hasPrevious: true)
        SubtensorDividerStyle.apply(to: feeCell, hasPrevious: true)
    }
}
