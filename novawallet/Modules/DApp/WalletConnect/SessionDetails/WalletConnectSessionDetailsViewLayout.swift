import UIKit

final class WalletConnectSessionDetailsViewLayout: SCLoadableActionLayoutView {
    let titleView: GenericPairValueView<DAppIconView, UILabel> = .create { view in
        view.setVerticalAndSpacing(24)
        view.stackView.alignment = .center
        view.sView.apply(style: .secondaryScreenTitle)
        view.sView.numberOfLines = 0
        view.fView.contentInsets = DAppIconLargeConstants.insets
    }

    var iconView: DAppIconView { titleView.fView }

    var titleLabel: UILabel { titleView.sView }

    let tableView = StackTableView()
    let walletCell = StackTableCell()
    let dappCell = StackTableCell()
    let networksCell = StackInfoTableCell()
    let statusCell = StackStatusCell()

    var actionLoadableView: LoadableActionView { genericActionView }

    override func setupStyle() {
        super.setupStyle()

        stackView.layoutMargins = UIEdgeInsets(top: 32.0, left: 16.0, bottom: 0.0, right: 16.0)

        actionLoadableView.actionButton.applyDestructiveDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 24)

        iconView.snp.makeConstraints { make in
            make.size.equalTo(DAppIconLargeConstants.size)
        }

        addArrangedSubview(tableView)

        tableView.addArrangedSubview(walletCell)
        tableView.addArrangedSubview(dappCell)
        tableView.addArrangedSubview(networksCell)
        tableView.addArrangedSubview(statusCell)
    }

    func bind(viewModel: WalletConnectSessionViewModel, locale: Locale) {
        iconView.bind(viewModel: viewModel.iconViewModel, size: DAppIconLargeConstants.displaySize)

        titleLabel.text = viewModel.title
        walletCell.bind(viewModel: viewModel.wallet?.cellViewModel)
        dappCell.bind(details: viewModel.host)

        networksCell.bindNetworks(viewModel: viewModel.networks, locale: locale)

        statusCell.bind(status: viewModel.status, locale: locale)
    }
}
