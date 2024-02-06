import UIKit

final class StakingConfirmProxyViewLayout: ScrollableContainerLayoutView {
    let detailsTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 4, right: 16)
    }

    let networkCell = StackNetworkCell()

    let proxiedWalletCell = StackTableCell()

    let proxiedAddressCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let proxyDepositView: ProxyDepositView = .create {
        $0.imageView.image = R.image.iconLock()!.withTintColor(R.color.colorIconSecondary()!)
        $0.contentInsets = .zero
    }

    let feeCell = StackNetworkFeeCell()

    let proxyTableView: StackTableView = .create {
        $0.cellHeight = 44
        $0.hasSeparators = true
        $0.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16)
    }

    let proxyTypeCell = StackTableCell()

    let proxyAddressCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let actionButton: LoadableActionView = .create {
        $0.actionButton.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16)

        addArrangedSubview(detailsTableView, spacingAfter: 8)
        addArrangedSubview(proxyTableView)

        detailsTableView.addArrangedSubview(networkCell)
        detailsTableView.addArrangedSubview(proxiedWalletCell)
        detailsTableView.addArrangedSubview(proxiedAddressCell)
        detailsTableView.addArrangedSubview(proxyDepositView)
        detailsTableView.addArrangedSubview(feeCell)

        proxyTableView.addArrangedSubview(proxyTypeCell)
        proxyTableView.addArrangedSubview(proxyAddressCell)
    }
}
