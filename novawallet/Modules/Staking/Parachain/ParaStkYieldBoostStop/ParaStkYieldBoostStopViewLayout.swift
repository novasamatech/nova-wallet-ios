import UIKit

final class ParaStkYieldBoostStopViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let senderTableView = StackTableView()

    let walletCell = StackTableCell()

    let senderCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let networkFeeCell = StackNetworkFeeCell()

    let parametersTableView = StackTableView()

    let collatorCell = StackTableCell()
    let stakingTypeCell = StackTableCell()

    let actionLoadableView = LoadableActionView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionLoadableView.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(senderTableView)
        containerView.stackView.setCustomSpacing(12.0, after: senderTableView)

        senderTableView.addArrangedSubview(walletCell)
        senderTableView.addArrangedSubview(senderCell)
        senderTableView.addArrangedSubview(networkFeeCell)

        containerView.stackView.addArrangedSubview(parametersTableView)
        parametersTableView.addArrangedSubview(collatorCell)
        parametersTableView.addArrangedSubview(stakingTypeCell)
    }
}
