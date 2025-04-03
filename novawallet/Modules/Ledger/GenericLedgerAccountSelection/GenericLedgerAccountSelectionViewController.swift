import UIKit
import Foundation_iOS

final class GenericLedgerAccountSelectionController: UIViewController, ViewHolder {
    typealias RootViewType = GenericLedgerAccountSelectionViewLayout

    let presenter: GenericLedgerAccountSelectionPresenterProtocol

    init(presenter: GenericLedgerAccountSelectionPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GenericLedgerAccountSelectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    private func setupHandlers() {
        rootView.loadMoreButton.addTarget(self, action: #selector(actionLoadNext), for: .touchUpInside)
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.ledgerAccountConfirmTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.loadMoreButton.setTitle(
            R.string.localizable.commonLoadMoreAccounts(preferredLanguages: selectedLocale.rLanguages)
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

extension GenericLedgerAccountSelectionController: GenericLedgerAccountSelectionViewProtocol {
    func didClearAccounts() {
        rootView.clearCells()
    }

    func didAddAccount(viewModel: LedgerAccountViewModel) {
        let cell = rootView.addCell()
        cell.bind(viewModel: viewModel)

        cell.addTarget(self, action: #selector(actionCell(_:)), for: .touchUpInside)
    }

    func didStartLoading() {
        rootView.loadMoreView.startLoading()
    }

    func didStopLoading() {
        rootView.loadMoreView.stopLoading()
    }
}

extension GenericLedgerAccountSelectionController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
