import UIKit
import Foundation_iOS

final class LedgerAccountConfirmationViewController: UIViewController, ViewHolder {
    typealias RootViewType = LedgerAccountConfirmationViewLayout

    let presenter: LedgerAccountConfirmationPresenterProtocol

    init(
        presenter: LedgerAccountConfirmationPresenterProtocol,
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
        view = LedgerAccountConfirmationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionLoadNext),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        rootView.headerView.valueTop.text = R.string.localizable.ledgerAccountConfirmTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonLoadMoreAccounts(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    @objc private func actionLoadNext() {
        presenter.loadNext()
    }

    @objc private func actionCell(_ cell: UIControl) {
        guard
            let accountCell = cell as? LedgerAccountStackCell,
            let index = rootView.cells.firstIndex(of: accountCell) else {
            return
        }

        presenter.selectAccount(at: index)
    }
}

extension LedgerAccountConfirmationViewController: LedgerAccountConfirmationViewProtocol {
    func didAddAccount(viewModel: LedgerAccountViewModel) {
        let cell = rootView.addCell()
        cell.bind(viewModel: viewModel)

        cell.addTarget(self, action: #selector(actionCell(_:)), for: .touchUpInside)
    }

    func didReceive(networkViewModel: NetworkViewModel) {
        rootView.chainView.bind(viewModel: networkViewModel)
    }

    func didStartLoading() {
        rootView.loadableActionButton.startLoading()
    }

    func didStopLoading() {
        rootView.loadableActionButton.stopLoading()
    }
}

extension LedgerAccountConfirmationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
