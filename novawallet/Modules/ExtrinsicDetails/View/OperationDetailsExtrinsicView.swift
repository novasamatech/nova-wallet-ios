import UIKit

final class OperationDetailsExtrinsicView: LocalizableView {
    let senderTableView = StackTableView()

    let transactionTableView: StackTableView = {
        let view = StackTableView()
        return view
    }()

    let senderView = StackInfoTableCell()
    let networkView: StackNetworkCell = {
        let view = StackNetworkCell()
        view.borderView.borderType = []
        return view
    }()

    let transactionHashView = StackInfoTableCell()
    let moduleView = StackTableCell()
    let callView: StackTableCell = {
        let view = StackTableCell()
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

    func bind(viewModel: OperationExtrinsicViewModel, networkViewModel: NetworkViewModel) {
        networkView.bind(viewModel: networkViewModel)

        senderView.detailsLabel.lineBreakMode = viewModel.sender.lineBreakMode
        senderView.bind(viewModel: viewModel.sender.cellViewModel)

        transactionHashView.bind(details: viewModel.transactionHash)

        moduleView.bind(details: viewModel.module)
        callView.bind(details: viewModel.call)
    }

    private func setupLocalization() {
        senderView.titleLabel.text = R.string.localizable.commonSender(
            preferredLanguages: locale.rLanguages
        )

        networkView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages
        )

        transactionHashView.titleLabel.text = R.string.localizable.commonTxId(
            preferredLanguages: locale.rLanguages
        )

        moduleView.titleLabel.text = R.string.localizable.commonModule(
            preferredLanguages: locale.rLanguages
        )

        callView.titleLabel.text = R.string.localizable.commonClose(
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

        addSubview(transactionTableView)
        transactionTableView.snp.makeConstraints { make in
            make.top.equalTo(senderView.snp.bottom).offset(12.0)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        transactionTableView.stackView.addArrangedSubview(transactionHashView)
        transactionTableView.stackView.addArrangedSubview(moduleView)
        transactionTableView.stackView.addArrangedSubview(callView)
    }
}
