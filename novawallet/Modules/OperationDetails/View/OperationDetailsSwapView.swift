import UIKit

final class OperationDetailsSwapView: ScrollableContainerLayoutView, LocalizableViewProtocol {
    let senderTableView = StackTableView()

    let pairsView = SwapPairView()
    let detailsTableView = StackTableView()
    let walletTableView = StackTableView()
    let transactionTableView = StackTableView()

    let rateCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
        $0.titleButton.imageWithTitleView?.iconImage = R.image.iconInfoFilledAccent()
    }

    let networkFeeCell = SwapNetworkFeeViewCell()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
        $0.infoIcon = R.image.iconInfoFilledAccent()
    }

    let transactionHashView: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
    }

    let actionButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    var locale: Locale = .current {
        didSet {
            if locale != oldValue {
                setup(locale: locale)
            }
        }
    }

    func bind(viewModel: OperationSwapViewModel) {
        pairsView.leftAssetView.bind(viewModel: viewModel.assetIn)
        pairsView.rigthAssetView.bind(viewModel: viewModel.assetOut)
        rateCell.bind(loadableViewModel: .loaded(value: viewModel.rate))
        networkFeeCell.bind(loadableViewModel: .loaded(value: .init(
            isEditable: false,
            balanceViewModel: viewModel.fee
        )))
        walletCell.bind(viewModel: .init(
            details: viewModel.wallet.walletName ?? "",
            imageViewModel: viewModel.wallet.walletIcon
        ))
        accountCell.bind(viewModel: .init(
            details: viewModel.wallet.address,
            imageViewModel: viewModel.wallet.addressIcon
        ))
        transactionHashView.bind(details: viewModel.transactionHash)
    }

    private func setup(locale: Locale) {
        rateCell.titleButton.imageWithTitleView?.title = R.string.localizable.swapsSetupDetailsRate(
            preferredLanguages: locale.rLanguages)
        networkFeeCell.titleButton.imageWithTitleView?.title = R.string.localizable.commonNetwork(
            preferredLanguages: locale.rLanguages)
        rateCell.titleButton.invalidateLayout()
        networkFeeCell.titleButton.invalidateLayout()

        walletCell.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: locale.rLanguages)
        accountCell.titleLabel.text = R.string.localizable.commonAccount(
            preferredLanguages: locale.rLanguages)
        transactionHashView.titleLabel.text = R.string.localizable.commonTxId(
            preferredLanguages: locale.rLanguages
        )
    }

    override func setupStyle() {
        backgroundColor = .clear
    }

    override func setupLayout() {
        super.setupLayout()

        stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 0, right: 16)
        addArrangedSubview(pairsView, spacingAfter: 8)
        addArrangedSubview(detailsTableView, spacingAfter: 8)
        addArrangedSubview(walletTableView, spacingAfter: 8)
        addArrangedSubview(transactionTableView)

        detailsTableView.addArrangedSubview(rateCell)
        detailsTableView.addArrangedSubview(networkFeeCell)
        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        transactionTableView.addArrangedSubview(transactionHashView)

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
