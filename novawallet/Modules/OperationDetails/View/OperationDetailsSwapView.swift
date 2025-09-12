import UIKit

final class OperationDetailsSwapView: LocalizableView {
    let senderTableView = StackTableView()

    let pairsView = SwapPairView()
    let detailsTableView = StackTableView()
    let walletTableView = StackTableView()
    let transactionTableView = StackTableView()

    let rateCell: SwapInfoViewCell = .create {
        $0.titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        $0.titleButton.imageWithTitleView?.titleFont = .regularFootnote
    }

    let networkFeeCell = SwapNetworkFeeViewCell()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = .create {
        $0.detailsLabel.lineBreakMode = .byTruncatingMiddle
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

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

        pairsView.leftAssetView.valueLabel.textColor = R.color.colorTextPrimary()
        pairsView.rigthAssetView.valueLabel.textColor = R.color.colorTextPositive()
    }

    private func setup(locale: Locale) {
        rateCell.titleButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.swapsSetupDetailsRate()
        networkFeeCell.titleButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonNetworkFee()
        rateCell.titleButton.invalidateLayout()
        networkFeeCell.titleButton.invalidateLayout()

        walletCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonWallet()
        accountCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonAccount()
        transactionHashView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonTxId()
    }

    func setupStyle() {
        backgroundColor = .clear
    }

    func setupLayout() {
        addSubview(pairsView)
        addSubview(detailsTableView)
        addSubview(walletTableView)
        addSubview(transactionTableView)

        pairsView.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
        }
        detailsTableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(pairsView.snp.bottom).offset(8)
        }
        walletTableView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.top.equalTo(detailsTableView.snp.bottom).offset(8)
        }
        transactionTableView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(walletTableView.snp.bottom).offset(8)
            $0.bottom.equalToSuperview().offset(24)
        }

        detailsTableView.addArrangedSubview(rateCell)
        detailsTableView.addArrangedSubview(networkFeeCell)
        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        transactionTableView.addArrangedSubview(transactionHashView)
    }
}
