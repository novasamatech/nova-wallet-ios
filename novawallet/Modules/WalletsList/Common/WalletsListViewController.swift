import UIKit
import Foundation_iOS

class WalletsListViewController<
    Layout: WalletsListViewLayout, Cell: WalletsListTableViewCellProtocol & UITableViewCell
>: UIViewController, ViewHolder, UITableViewDataSource, UITableViewDelegate {
    typealias RootViewType = Layout

    let basePresenter: WalletsListPresenterProtocol

    init(basePresenter: WalletsListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.basePresenter = basePresenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = RootViewType()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()

        basePresenter.setup()
    }

    func setupLocalization() {}

    private func setupTableView() {
        rootView.tableView.registerClassForCell(Cell.self)
        rootView.tableView.registerHeaderFooterView(withClass: RoundedIconTitleHeaderView.self)

        rootView.tableView.rowHeight = 48.0

        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
    }

    // MARK: UITableView Data Source

    func numberOfSections(in _: UITableView) -> Int {
        basePresenter.numberOfSections()
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        basePresenter.numberOfItems(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(Cell.self, forIndexPath: indexPath)

        let item = basePresenter.item(at: indexPath.row, in: indexPath.section)
        cell.bind(viewModel: item)

        return cell
    }

    private func dequeueCommonHeader(from tableView: UITableView) -> RoundedIconTitleHeaderView {
        let view: RoundedIconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        view.contentInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 8.0, right: 16.0)
        return view
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = basePresenter.section(at: section)

        let icon: UIImage?
        let title: String?

        switch section.type {
        case .secrets:
            icon = nil
            title = nil
        case .watchOnly:
            icon = R.image.iconWatchOnlyHeader()
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonWatchOnly().uppercased()
        case .paritySigner:
            icon = ParitySignerType.legacy.iconForHeader
            title = ParitySignerType.legacy.getName(for: selectedLocale).uppercased()
        case .polkadotVault:
            icon = ParitySignerType.vault.iconForHeader
            title = ParitySignerType.vault.getName(for: selectedLocale).uppercased()
        case .ledger:
            icon = R.image.iconLedgerHeaderWarning()
            title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonLedgerLegacy().uppercased()
        case .proxied:
            icon = R.image.iconProxy()
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonProxieds().uppercased()
        case .multisig:
            icon = R.image.iconMultisigWallet()
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonMultisig().uppercased()
        case .genericLedger:
            icon = R.image.iconLedgerHeader()
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonLedger().uppercased()
        }

        guard let title, let icon else { return nil }

        let view = dequeueCommonHeader(from: tableView)
        view.bind(title: title, icon: icon)

        return view
    }

    // MARK: UITableView Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = basePresenter.section(at: section)

        switch section.type {
        case .secrets:
            return 0.0
        case .watchOnly,
             .paritySigner,
             .polkadotVault,
             .ledger,
             .proxied,
             .genericLedger,
             .multisig:
            return 46.0
        }
    }

    func tableView(_: UITableView, canMoveRowAt _: IndexPath) -> Bool {
        false
    }

    func tableView(
        _: UITableView,
        moveRowAt _: IndexPath,
        to _: IndexPath
    ) {}

    func tableView(
        _: UITableView,
        targetIndexPathForMoveFromRowAt _: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        proposedDestinationIndexPath
    }

    func tableView(
        _: UITableView,
        editingStyleForRowAt _: IndexPath
    ) -> UITableViewCell.EditingStyle {
        .none
    }

    func tableView(
        _: UITableView,
        commit _: UITableViewCell.EditingStyle,
        forRowAt _: IndexPath
    ) {}
}

extension WalletsListViewController: WalletsListViewProtocol {
    func didReload() {
        rootView.tableView.reloadData()
    }
}

extension WalletsListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
