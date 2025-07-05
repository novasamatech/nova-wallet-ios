import UIKit
import Foundation_iOS

final class MultisigTxDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigTxDetailsViewLayout

    let presenter: MultisigTxDetailsPresenterProtocol

    init(presenter: MultisigTxDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MultisigTxDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupHandlers()
    }
}

// MARK: - Private

private extension MultisigTxDetailsViewController {
    func setupHandlers() {
        rootView.depositorWalletCell.addTarget(
            self,
            action: #selector(actionDepositorInfo),
            for: .touchUpInside
        )
        rootView.callHashCell.addTarget(
            self,
            action: #selector(actionCallHash),
            for: .touchUpInside
        )
        rootView.callDataCell.addTarget(
            self,
            action: #selector(actionCallData),
            for: .touchUpInside
        )
        rootView.depositCell.addTarget(
            self,
            action: #selector(actionDepositInfo),
            for: .touchUpInside
        )
    }

    @objc func actionDepositorInfo() {
        presenter.actionDepositorInfo()
    }

    @objc func actionCallHash() {
        presenter.actionCallHash()
    }

    @objc func actionCallData() {
        presenter.actionCallData()
    }
    
    @objc func actionDepositInfo() {
        presenter.actionDepositInfo()
    }
}

// MARK: - MultisigTxDetailsViewProtocol

extension MultisigTxDetailsViewController: MultisigTxDetailsViewProtocol {
    func didReceive(viewModel: MultisigTxDetailsViewModel) {
        title = viewModel.title
        rootView.bind(viewModel: viewModel)
    }

    func didReceive(
        depositViewModel: MultisigTxDetailsViewModel.SectionField<BalanceViewModelProtocol>
    ) {
        rootView.bind(deposit: depositViewModel)
    }
}
