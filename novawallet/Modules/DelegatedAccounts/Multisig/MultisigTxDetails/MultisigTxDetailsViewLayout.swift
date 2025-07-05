import UIKit
import UIKit_iOS

final class MultisigTxDetailsViewLayout: ScrollableContainerLayoutView {
    // MARK: - Sender

    let depositorTableView = StackTableView()

    let depositorWalletCell = StackInfoTableCell()

    let depositCell = StackNetworkFeeCell()

    // MARK: - Call Data

    let callDataTableView = StackTableView()

    let callHashCell: StackInfoTableCell = .create { view in
        view.titleLabel.lineBreakMode = .byTruncatingMiddle
    }

    let callDataCell: StackInfoTableCell = .create { view in
        view.titleLabel.lineBreakMode = .byTruncatingMiddle
    }

    // MARK: - Call JSON

    let backgroundView: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorContainerBackground()!
        view.highlightedFillColor = R.color.colorContainerBackground()!
        view.strokeColor = R.color.colorContainerBorder()!
        view.highlightedStrokeColor = R.color.colorContainerBorder()!
        view.strokeWidth = 0.5
        view.cornerRadius = 12.0
    }

    let hintLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
    }

    let detailsLabel: UILabel = .create { label in
        label.apply(style: .sourceCodePrimary)
        label.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension MultisigTxDetailsViewLayout {
    func setupDepositSection(with viewModel: MultisigTxDetailsViewModel.Deposit) {
        depositorTableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        stackView.addArrangedSubview(depositorTableView)
        stackView.setCustomSpacing(Constants.interSectionSpacing, after: depositorTableView)

        depositorTableView.addArrangedSubview(depositorWalletCell)
        depositorTableView.addArrangedSubview(depositCell)

        depositorWalletCell.titleLabel.text = viewModel.depositor.title
        depositorWalletCell.titleLabel.lineBreakMode = viewModel.depositor.value.lineBreakMode
        depositorWalletCell.bind(viewModel: viewModel.depositor.value.cellViewModel)

        depositCell.rowContentView.titleLabel.text = viewModel.deposit.title
        depositCell.rowContentView.bind(viewModel: viewModel.deposit.value)
    }

    func setupCallDataSection(with viewModel: MultisigTxDetailsViewModel.CallData) {
        callDataTableView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        stackView.addArrangedSubview(callDataTableView)
        stackView.setCustomSpacing(
            Constants.lastSectionSpacing,
            after: callDataTableView
        )

        callDataTableView.addArrangedSubview(callHashCell)
        callDataTableView.addArrangedSubview(callDataCell)

        callHashCell.titleLabel.text = viewModel.callHash.title
        callHashCell.bind(viewModel: viewModel.callHash.value)

        if let callDataField = viewModel.callData {
            callDataCell.titleLabel.text = callDataField.title
            callDataCell.bind(viewModel: callDataField.value)
        }
    }

    func setupCallJsonSection(with viewModel: MultisigTxDetailsViewModel.SectionField<String>) {
        stackView.addArrangedSubview(hintLabel)
        stackView.setCustomSpacing(
            Constants.hintBottomSpacing,
            after: hintLabel
        )

        stackView.addArrangedSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        backgroundView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.jsonContentInsets)
        }

        hintLabel.text = viewModel.title
        detailsLabel.text = viewModel.value
    }
}

// MARK: - Internal

extension MultisigTxDetailsViewLayout {
    func bind(viewModel: MultisigTxDetailsViewModel) {
        containerView.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        viewModel.sections.forEach { section in
            switch section {
            case let .deposit(depositModel):
                setupDepositSection(with: depositModel)
            case let .callData(callDataModel):
                setupCallDataSection(with: callDataModel)
            case let .callJson(callJsonModel):
                setupCallJsonSection(with: callJsonModel)
            }
        }
    }

    func bind(deposit viewModel: MultisigTxDetailsViewModel.SectionField<BalanceViewModelProtocol>) {
        depositCell.rowContentView.titleLabel.text = viewModel.title
        depositCell.rowContentView.bind(viewModel: viewModel.value)
    }
}

// MARK: - Constants

private extension MultisigTxDetailsViewLayout {
    enum Constants {
        static let interSectionSpacing: CGFloat = 8.0
        static let hintBottomSpacing: CGFloat = 12.0
        static let lastSectionSpacing: CGFloat = 16.0
        static let jsonContentInsets: CGFloat = 12.0
    }
}
