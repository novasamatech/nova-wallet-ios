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

        switch section.type {
        case .secrets:
            return nil
        case .watchOnly:
            let view = dequeueCommonHeader(from: tableView)
            let icon = R.image.iconWatchOnlyHeader()
            let title = R.string.localizable.commonWatchOnly(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()

            view.bind(title: title, icon: icon)
            return view
        case .paritySigner:
            let view = dequeueCommonHeader(from: tableView)
            let icon = ParitySignerType.legacy.iconForHeader
            let title = ParitySignerType.legacy.getName(for: selectedLocale).uppercased()

            view.bind(title: title, icon: icon)
            return view
        case .polkadotVault:
            let view = dequeueCommonHeader(from: tableView)
            let icon = ParitySignerType.vault.iconForHeader
            let title = ParitySignerType.vault.getName(for: selectedLocale).uppercased()

            view.bind(title: title, icon: icon)
            return view
        case .ledger:
            let view = dequeueCommonHeader(from: tableView)
            let icon = R.image.iconLedgerHeaderWarning()
            let title = R.string.localizable.commonLedgerLegacy(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()

            view.bind(title: title, icon: icon)
            return view
        case .proxied:
            let view = dequeueCommonHeader(from: tableView)
            let icon = R.image.iconProxy()
            let title = R.string.localizable.commonProxieds(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()

            view.bind(title: title, icon: icon)
            return view
        case .genericLedger:
            let view = dequeueCommonHeader(from: tableView)
            let icon = R.image.iconLedgerHeader()
            let title = R.string.localizable.commonLedger(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()

            view.bind(title: title, icon: icon)
            return view
        }
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
        case .watchOnly, .paritySigner, .polkadotVault, .ledger, .proxied, .genericLedger:
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
