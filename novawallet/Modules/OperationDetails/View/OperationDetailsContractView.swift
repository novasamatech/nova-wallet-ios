import UIKit

final class OperationDetailsContractView: LocalizableView {
    let senderTableView = StackTableView()
    let contractTableView = StackTableView()
    let transactionTableView = StackTableView()

    let senderView = StackInfoTableCell()
    let networkView = StackNetworkCell()

    let contractView: StackInfoTableCell = {
        let view = StackInfoTableCell()
        view.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return view
    }()

    let transactionHashView: StackInfoTableCell = {
        let view = StackInfoTableCell()
        view.detailsLabel.lineBreakMode = .byTruncatingMiddle
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

    func bind(viewModel: OperationContractCallViewModel, networkViewModel: NetworkViewModel) {
        networkView.bind(viewModel: networkViewModel)

        senderView.detailsLabel.lineBreakMode = viewModel.sender.lineBreakMode
        senderView.bind(viewModel: viewModel.sender.cellViewModel)

        contractView.detailsLabel.lineBreakMode = viewModel.contract.lineBreakMode
        contractView.bind(viewModel: viewModel.contract.cellViewModel)

        transactionHashView.bind(details: viewModel.transactionHash)
    }

    private func setupLocalization() {
        senderView.titleLabel.text = R.string.localizable.commonSender(
            preferredLanguages: locale.rLanguages
        )

        networkView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages
        )

        contractView.titleLabel.text = R.string.localizable.evmContract(
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

        senderTableView.addArrangedSubview(senderView)
        senderTableView.addArrangedSubview(networkView)

        addSubview(contractTableView)
        contractTableView.snp.makeConstraints { make in
            make.top.equalTo(senderTableView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
        }

        contractTableView.addArrangedSubview(contractView)

        addSubview(transactionTableView)
        transactionTableView.snp.makeConstraints { make in
            make.top.equalTo(contractTableView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        transactionTableView.addArrangedSubview(transactionHashView)
    }
}
