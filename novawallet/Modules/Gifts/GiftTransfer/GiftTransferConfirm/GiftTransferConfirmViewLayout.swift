import UIKit
import Foundation
import Foundation_iOS

final class GiftTransferConfirmViewLayout: SCLoadableActionLayoutView {
    let amountView = MultilineBalanceView()

    let stackTableView = StackTableView()

    let networkCell = StackNetworkCell()

    let walletCell = StackTableCell()

    let senderCell: StackInfoTableCell = .create { view in
        view.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let giftAmountCell = StackGiftAmountCell()

    let networkFeeCell = StackNetworkFeeCell()
    let claimFeeCell = StackNetworkFeeCell()

    let tooltipLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(amountView, spacingAfter: 20.0)
        addArrangedSubview(stackTableView, spacingAfter: 12.0)

        stackTableView.addArrangedSubview(networkCell)
        stackTableView.addArrangedSubview(walletCell)
        stackTableView.addArrangedSubview(senderCell)
        stackTableView.addArrangedSubview(giftAmountCell)
        stackTableView.addArrangedSubview(networkFeeCell)
        stackTableView.addArrangedSubview(claimFeeCell)

        addSubview(tooltipLabel)

        tooltipLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(genericActionView.snp.top).offset(-16)
        }
    }
}
