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
        rootView.confirmButton.removeTarget(
            self,
            action: #selector(actionApprove),
            for: .touchUpInside
        )
        rootView.confirmButton.removeTarget(
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
    }

    func addButtonActions() {
        guard let viewModel else { return }

        let languages = selectedLocale.rLanguages

        viewModel.actions.forEach { action in
            switch action {
            case .approve:
                rootView.confirmButton.addTarget(
                    self,
                    action: #selector(actionApprove),
                    for: .touchUpInside
                )
                rootView.bindApprove(
                    title: R.string.localizable.commonApproveAndExecute(preferredLanguages: languages)
                )
            case .reject:
                rootView.confirmButton.addTarget(
                    self,
                    action: #selector(actionReject),
                    for: .touchUpInside
                )
                rootView.bindReject(
                    title: R.string.localizable.commonReject(preferredLanguages: languages)
                )
            case .addCallData:
                rootView.callDataButton.addTarget(
                    self,
                    action: #selector(actionCallData),
                    for: .touchUpInside
                )
                rootView.bindCallDataButton(
                    title: R.string.localizable.enterCallDataDetailsButtonTitle(preferredLanguages: languages)
                )
            }
        }
    }

    @objc func actionMultisigWallet() {
        presenter.actionShowSender()
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
        let actionClosure: (() -> Void)? = viewModel?.actions.compactMap { action -> (() -> Void)? in
            guard case let .approve(closure) = action else { return nil }

            return closure
        }.first

        actionClosure?()
    }

    @objc func actionReject() {
        let actionClosure: (() -> Void)? = viewModel?.actions.compactMap { action -> (() -> Void)? in
            guard case let .reject(closure) = action else { return nil }

            return closure
        }.first

        actionClosure?()
    }

    @objc func actionCallData() {
        let actionClosure: (() -> Void)? = viewModel?.actions.compactMap { action -> (() -> Void)? in
            guard case let .addCallData(closure) = action else { return nil }

            return closure
        }.first

        actionClosure?()
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

    func didReceive(feeViewModel: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>) {
        rootView.bind(fee: feeViewModel)
    }
}

// MARK: - Localizable

extension MultisigOperationConfirmViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
