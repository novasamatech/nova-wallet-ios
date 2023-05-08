import UIKit

final class DAppWalletAuthViewLayout: SCGenericActionLayoutView<UIStackView> {
    let sourceAppIconView: DAppIconView = .create { view in
        view.contentInsets = DAppIconLargeConstants.insets
    }

    let destinationAppIconView: DAppIconView = .create { view in
        view.contentInsets = DAppIconLargeConstants.insets
    }

    let accessImageView: UIImageView = .create { view in
        view.image = R.image.iconDappAccess()!
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.textAlignment = .center
        view.numberOfLines = 3
    }

    let subtitleLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.textAlignment = .center
        view.numberOfLines = 2
    }

    let dappTableView = StackTableView()
    let dappCell = StackTableCell()
    let networksCell = StackInfoTableCell()

    let walletTableView = StackTableView()
    let walletCell = StackWalletAmountCell()

    private(set) var rejectButton: TriangularedButton?
    private(set) var approveButton: TriangularedButton?

    private(set) var networksWarningView: InlineAlertView?
    private(set) var walletWarningView: InlineAlertView?

    func setupRejectButton() {
        guard rejectButton == nil else {
            return
        }

        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        genericActionView.insertArrangedSubview(button, at: 0)

        rejectButton = button
    }

    func setupApproveButton() {
        guard approveButton == nil else {
            return
        }

        let button = TriangularedButton()
        button.applyEnabledStyle()
        genericActionView.addArrangedSubview(button)

        approveButton = button
    }

    func removeApproveButton() {
        approveButton?.removeFromSuperview()
        approveButton = nil
    }

    func applyNetworksWarning(text: String?) {
        applyWarning(
            on: &networksWarningView,
            after: dappTableView,
            text: text,
            spacing: 8.0
        )
    }

    func applyWalletWarning(text: String?) {
        applyWarning(
            on: &walletWarningView,
            after: walletTableView,
            text: text,
            spacing: 8.0
        )
    }

    override func setupLayout() {
        super.setupLayout()

        genericActionView.axis = .horizontal
        genericActionView.spacing = 16

        let headerView = UIView()

        headerView.addSubview(accessImageView)
        accessImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(36.0)
            make.centerX.equalToSuperview()
        }

        headerView.addSubview(sourceAppIconView)
        sourceAppIconView.snp.makeConstraints { make in
            make.centerY.equalTo(accessImageView.snp.centerY)
            make.trailing.equalTo(accessImageView.snp.leading).offset(-8.0)
            make.size.equalTo(DAppIconLargeConstants.size)
        }

        headerView.addSubview(destinationAppIconView)
        destinationAppIconView.snp.makeConstraints { make in
            make.centerY.equalTo(accessImageView.snp.centerY)
            make.leading.equalTo(accessImageView.snp.trailing).offset(8.0)
            make.size.equalTo(DAppIconLargeConstants.size)
        }

        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(112.0)
        }

        headerView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
            make.bottom.equalToSuperview()
        }

        addArrangedSubview(headerView, spacingAfter: 24)

        addArrangedSubview(dappTableView, spacingAfter: 8)
        dappTableView.addArrangedSubview(dappCell)
        dappTableView.addArrangedSubview(networksCell)

        addArrangedSubview(walletTableView, spacingAfter: 8)
        walletTableView.addArrangedSubview(walletCell)
    }
}
