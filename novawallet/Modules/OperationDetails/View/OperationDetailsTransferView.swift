import UIKit

final class OperationDetailsTransferView: LocalizableView {
    let senderTableView = StackTableView()
    let recepientTableView = StackTableView()
    let transactionTableView = StackTableView()

    let senderView = StackInfoTableCell()
    let networkView = StackNetworkCell()
    let networkFeeView = StackNetworkFeeCell()

    let recepientView: StackInfoTableCell = {
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

    func bind(viewModel: OperationTransferViewModel, networkViewModel: NetworkViewModel) {
        networkView.bind(viewModel: networkViewModel)

        senderView.detailsLabel.lineBreakMode = viewModel.sender.lineBreakMode
        senderView.bind(viewModel: viewModel.sender.cellViewModel)

        networkFeeView.rowContentView.bind(viewModel: viewModel.fee)

        recepientView.detailsLabel.lineBreakMode = viewModel.recepient.lineBreakMode
        recepientView.bind(viewModel: viewModel.recepient.cellViewModel)

        transactionHashView.bind(details: viewModel.transactionHash)
    }

    private func setupLocalization() {
        senderView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonSender()

        networkView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonNetwork()

        networkFeeView.rowContentView.locale = locale

        recepientView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonRecipient()

        transactionHashView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonTxId()
    }

    private func setupLayout() {
        addSubview(senderTableView)
        senderTableView.snp.makeConstraints { make in
            make.top.trailing.leading.equalToSuperview()
        }

        senderTableView.addArrangedSubview(senderView)
        senderTableView.addArrangedSubview(networkView)
        senderTableView.addArrangedSubview(networkFeeView)

        addSubview(recepientTableView)
        recepientTableView.snp.makeConstraints { make in
            make.top.equalTo(senderTableView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
        }

        recepientTableView.addArrangedSubview(recepientView)

        addSubview(transactionTableView)
        transactionTableView.snp.makeConstraints { make in
            make.top.equalTo(recepientTableView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        transactionTableView.addArrangedSubview(transactionHashView)
    }
}
