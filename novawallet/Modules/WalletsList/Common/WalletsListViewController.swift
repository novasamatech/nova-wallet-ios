import UIKit
import SoraFoundation

class WalletsListViewController<Cell: WalletsListTableViewCell>: UIViewController, ViewHolder,
    UITableViewDataSource, UITableViewDelegate {
    typealias RootViewType = WalletsListViewLayout

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
        view = WalletsListViewLayout()
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

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = basePresenter.section(at: section)

        switch section.type {
        case .secrets:
            return nil
        case .watchOnly:
            let view: RoundedIconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
            view.contentInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 8.0, right: 16.0)
            let icon = R.image.iconWatchOnlyHeader()
            let title = R.string.localizable.commonWatchOnly(
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
        case .watchOnly:
            return 46.0
        }
    }
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
