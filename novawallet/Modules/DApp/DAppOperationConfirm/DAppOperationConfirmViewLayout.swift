import UIKit
import UIKit_iOS

final class DAppOperationConfirmViewLayout: SCGenericActionLayoutView<UIStackView> {
    static let listImageSize = CGSize(width: 24, height: 24)

    let iconView: DAppIconView = .create { view in
        view.contentInsets = DAppIconLargeConstants.insets
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.textAlignment = .center
    }

    let subtitleLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.numberOfLines = 3
        view.textAlignment = .center
    }

    let dAppTableView: StackTableView = .create { view in
        view.cellHeight = 52
    }

    let dAppCell = StackTableCell()

    let senderTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let networkCell = StackTableCell()

    let feeCell = StackNetworkFeeCell()

    let transactionDetailsTableView: StackTableView = .create { view in
        view.cellHeight = 52
    }

    let transactionDetailsCell: StackActionCell = .create { view in
        view.rowContentView.iconSize = 0
        view.titleLabel.apply(style: .footnoteSecondary)
    }

    let rejectButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
    }

    let confirmButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        genericActionView.axis = .horizontal
        genericActionView.distribution = .fillEqually
        genericActionView.spacing = 16

        genericActionView.addArrangedSubview(rejectButton)
        genericActionView.addArrangedSubview(confirmButton)

        let headerView = UIView()

        headerView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(88.0)
        }

        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(iconView.snp.bottom).offset(20.0)
        }

        headerView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
            make.bottom.equalToSuperview()
        }

        addArrangedSubview(headerView, spacingAfter: 24)

        addArrangedSubview(dAppTableView, spacingAfter: 8)
        dAppTableView.addArrangedSubview(dAppCell)

        addArrangedSubview(senderTableView, spacingAfter: 8)
        senderTableView.addArrangedSubview(walletCell)
        senderTableView.addArrangedSubview(accountCell)
        senderTableView.addArrangedSubview(networkCell)
        senderTableView.addArrangedSubview(feeCell)

        addArrangedSubview(transactionDetailsTableView, spacingAfter: 8)
        transactionDetailsTableView.addArrangedSubview(transactionDetailsCell)
    }

    func setupNetworkCell(with viewModel: StackCellViewModel?) {
        if let viewModel {
            senderTableView.insertArranged(
                view: networkCell,
                after: accountCell
            )
            networkCell.bind(
                viewModel: viewModel,
                cornerRadius: nil
            )
        } else {
            networkCell.removeFromSuperview()
        }
    }
}
