import UIKit
import SnapKit

final class StakingRewardDetailsViewLayout: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = NavigationBarStyle.defaultStyle.titleAttributes?[.font] as? UIFont
        return label
    }()

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let iconView = AssetIconView.standaloneRewards()

    let amountView = MultilineBalanceView()

    let rewardTableView = StackTableView()

    let validatorCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let eraCell = StackTableCell()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

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
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        let iconContainerView = UIView()
        containerView.stackView.addArrangedSubview(iconContainerView)

        iconContainerView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.bottom.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }

        containerView.stackView.setCustomSpacing(12.0, after: iconContainerView)

        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.setCustomSpacing(24.0, after: amountView)

        containerView.stackView.addArrangedSubview(rewardTableView)

        rewardTableView.addArrangedSubview(validatorCell)
        rewardTableView.addArrangedSubview(eraCell)
    }
}
