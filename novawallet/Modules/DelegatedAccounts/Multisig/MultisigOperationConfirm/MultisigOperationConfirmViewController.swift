import UIKit
import Foundation_iOS

final class MultisigOperationConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultisigOperationConfirmViewLayout

    let presenter: MultisigOperationConfirmPresenterProtocol

    var viewModel: MultisigOperationConfirmViewModel?

    init(
        presenter: MultisigOperationConfirmPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = MultisigOperationConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setupLocalization()
    }
}

// MARK: - Private

private extension MultisigOperationConfirmViewController {
    func setupLocalization() {
        rootView.signatoryListView.set(locale: selectedLocale)
    }

    func setupActions() {
        clearActions()
        addActions()
    }

    func clearActions() {
        clearButtonActions()
        clearInfoActions()
    }

    func addActions() {
        addInfoActions()
        addButtonActions()
    }

    func clearInfoActions() {
        rootView.multisigWalletCell.removeTarget(
            self,
            action: #selector(actionMultisigWallet),
            for: .touchUpInside
        )
        rootView.signatoryWalletCell.removeTarget(
            self,
            action: #selector(actionCurrentSignatory),
            for: .touchUpInside
        )
        rootView.signatoryListView.rows.forEach {
            $0.removeTarget(
                self,
                action: #selector(actionSignatory(sender:)),
                for: .touchUpInside
            )
        }
    }

    func clearButtonActions() {
        rootView.confirmButton.actionButton.removeTarget(
            self,
            action: #selector(actionApprove),
            for: .touchUpInside
        )
        rootView.confirmButton.actionButton.removeTarget(
            self,
            action: #selector(actionReject),
            for: .touchUpInside
        )
        rootView.callDataButton.removeTarget(
            self,
            action: #selector(actionCallData),
            for: .touchUpInside
        )
    }

    func addInfoActions() {
        rootView.multisigWalletCell.addTarget(
            self,
            action: #selector(actionMultisigWallet),
            for: .touchUpInside
        )
        rootView.delegatedAccountCell.addTarget(
            self,
            action: #selector(actionDelegatedAccount),
            for: .touchUpInside
        )
        rootView.recipientCell.addTarget(
            self,
            action: #selector(actionRecipient),
            for: .touchUpInside
        )
        rootView.signatoryWalletCell.addTarget(
            self,
            action: #selector(actionCurrentSignatory),
            for: .touchUpInside
        )
        rootView.signatoryListView.rows.forEach {
            $0.addTarget(
                self,
                action: #selector(actionSignatory(sender:)),
                for: .touchUpInside
            )
        }
        rootView.fullDetailsCell.addTarget(
            self, action: #selector(actionFullDetails),
            for: .touchUpInside
        )
    }

    func addButtonActions() {
        guard let viewModel else { return }

        viewModel.actions.forEach { action in
            switch action.type {
            case .approve:
                rootView.confirmButton.actionButton.addTarget(
                    self,
                    action: #selector(actionApprove),
                    for: .touchUpInside
                )
                rootView.bindApprove(title: action.title)
            case .reject:
                rootView.confirmButton.actionButton.addTarget(
                    self,
                    action: #selector(actionReject),
                    for: .touchUpInside
                )
                rootView.bindReject(title: action.title)
            case .addCallData:
                rootView.callDataButton.addTarget(
                    self,
                    action: #selector(actionCallData),
                    for: .touchUpInside
                )
                rootView.bindCallDataButton(action.title)
            }
        }

        if !viewModel.hasAddCallDataAction {
            rootView.bindCallDataButton(nil)
        }
    }

    @objc func actionMultisigWallet() {
        presenter.actionShowSender()
    }

    @objc func actionDelegatedAccount() {
        presenter.actionShowDelegated()
    }

    @objc func actionRecipient() {
        presenter.actionShowRecipient()
    }

    @objc func actionCurrentSignatory() {
        presenter.actionShowCurrentSignatory()
    }

    @objc func actionSignatory(sender: UIView) {
        guard
            let control = sender as? WalletInfoCheckmarkControl,
            let identifier = control.model?.identifier
        else {
            return
        }

        presenter.actionShowSignatory(with: identifier)
    }

    @objc func actionApprove() {
        let actionClosure = viewModel?.actions.first { $0.type == .approve }?.actionClosure

        actionClosure?()
    }

    @objc func actionReject() {
        let actionClosure = viewModel?.actions.first { $0.type == .reject }?.actionClosure

        actionClosure?()
    }

    @objc func actionCallData() {
        let actionClosure = viewModel?.actions.first { $0.type == .addCallData }?.actionClosure

        actionClosure?()
    }

    @objc func actionFullDetails() {
        presenter.actionFullDetails()
    }
}

// MARK: - MultisigOperationConfirmViewProtocol

extension MultisigOperationConfirmViewController: MultisigOperationConfirmViewProtocol {
    func didReceive(viewModel: MultisigOperationConfirmViewModel) {
        self.viewModel = viewModel
        title = viewModel.title

        rootView.bind(viewModel: viewModel)

        setupActions()
    }

    func didReceive(
        feeViewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>
    ) {
        rootView.bind(fee: feeViewModel)
    }

    func didReceive(amount: BalanceViewModelProtocol?) {
        rootView.bind(amount: amount)
    }

    func didReceive(loading: Bool) {
        if loading {
            rootView.confirmButton.startLoading()
        } else {
            rootView.confirmButton.stopLoading()
        }
    }
}

// MARK: - Localizable

extension MultisigOperationConfirmViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
