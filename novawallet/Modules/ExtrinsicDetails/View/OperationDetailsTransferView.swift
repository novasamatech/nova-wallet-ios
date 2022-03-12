import UIKit

final class OperationDetailsTransferView: LocalizableView {
    let senderTableView = StackTableView()
    let recepientTableView: StackTableView = {
        let view = StackTableView()
        view.stackView.layoutMargins = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
        return view
    }()

    let transactionTableView: StackTableView = {
        let view = StackTableView()
        view.stackView.layoutMargins = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
        return view
    }()

    let senderView = StackInfoTableCell()
    let networkView = StackNetworkCell()
    let networkFeeView: StackTableCell = {
        let view = StackTableCell()
        view.borderView.borderType = []
        return view
    }()

    let recepientView: StackInfoTableCell = {
        let view = StackInfoTableCell()
        view.detailsLabel.lineBreakMode = .byTruncatingMiddle
        view.borderView.borderType = []
        return view
    }()

    let transactionHashView: StackInfoTableCell = {
        let view = StackInfoTableCell()
        view.detailsLabel.lineBreakMode = .byTruncatingMiddle
        view.borderView.borderType = []
        return view
    }()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: OperationTransferViewModel, networkViewModel: NetworkViewModel) {
        networkView.bind(viewModel: networkViewModel)

        senderView.detailsLabel.lineBreakMode = viewModel.sender.lineBreakMode
        senderView.bind(viewModel: viewModel.sender.cellViewModel)

        let feeViewModel = StackCellViewModel(details: viewModel.fee, imageViewModel: nil)
        networkFeeView.bind(viewModel: feeViewModel)

        recepientView.detailsLabel.lineBreakMode = viewModel.recepient.lineBreakMode
        recepientView.bind(viewModel: viewModel.recepient.cellViewModel)

        let transactionViewModel = StackCellViewModel(
            details: viewModel.transactionHash,
            imageViewModel: nil
        )

        transactionHashView.bind(viewModel: transactionViewModel)
    }

    private func setupLocalization() {
        senderView.titleLabel.text = R.string.localizable.commonSender(
            preferredLanguages: locale.rLanguages
        )

        networkView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages
        )

        networkFeeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )

        recepientView.titleLabel.text = R.string.localizable.commonRecipient(
            preferredLanguages: locale.rLanguages
        )

        transactionHashView.titleLabel.text = R.string.localizable.commonTxId(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(senderTableView)
        senderTableView.snp.makeConstraints { make in
            make.top.trailing.leading.equalToSuperview()
        }

        senderTableView.stackView.addArrangedSubview(senderView)
        senderTableView.stackView.addArrangedSubview(networkView)
        senderTableView.stackView.addArrangedSubview(networkFeeView)

        addSubview(recepientTableView)
        recepientTableView.snp.makeConstraints { make in
            make.top.equalTo(senderTableView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
        }

        recepientTableView.stackView.addArrangedSubview(recepientView)

        addSubview(transactionTableView)
        transactionTableView.snp.makeConstraints { make in
            make.top.equalTo(recepientTableView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        transactionTableView.stackView.addArrangedSubview(transactionHashView)
    }
}
