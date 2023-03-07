import UIKit

final class StakingRebagConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = .create {
        $0.stackView.isLayoutMarginsRelativeArrangement = true
        $0.stackView.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        $0.stackView.alignment = .fill
    }

    let walletSectionView = StackTableView()
    let walletCell = StackTableCell()
    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let networkFeeCell = StackNetworkFeeCell()

    let rebagSectionView = StackTableView()
    let currentBagList = StackTableCell()
    let nextBagList = StackTableCell()

    let hintView = HintListView()

    let actionLoadableView = LoadableActionView()
    var confirmButton: TriangularedButton {
        actionLoadableView.actionButton
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(actionLoadableView)
        actionLoadableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            $0.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(walletSectionView)
        walletSectionView.addArrangedSubview(walletCell)
        walletSectionView.addArrangedSubview(accountCell)
        walletSectionView.addArrangedSubview(networkFeeCell)
        containerView.stackView.setCustomSpacing(8, after: walletSectionView)

        containerView.stackView.addArrangedSubview(rebagSectionView)
        rebagSectionView.addArrangedSubview(currentBagList)
        rebagSectionView.addArrangedSubview(nextBagList)
        containerView.stackView.setCustomSpacing(16, after: rebagSectionView)

        containerView.stackView.addArrangedSubview(hintView)
    }
}
