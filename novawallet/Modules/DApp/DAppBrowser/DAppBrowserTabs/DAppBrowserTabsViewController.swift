import UIKit

typealias DappBrowserTabCell = PlainBaseTableViewCell<UILabel>

final class DAppBrowserTabsViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserTabsViewLayout

    let presenter: DAppBrowserTabsPresenterProtocol

    var viewModels: [DAppBrowserTabModel] = []

    init(presenter: DAppBrowserTabsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppBrowserTabsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()

        presenter.setup()
    }

    func setup() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.registerClassForCell(DappBrowserTabCell.self)
    }
}

extension DAppBrowserTabsViewController: UITableViewDataSource {
    func tableView(
        _: UITableView,
        numberOfRowsInSection _: Int
    ) -> Int {
        viewModels.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(
            DappBrowserTabCell.self,
            forIndexPath: indexPath
        )

        cell.contentDisplayView.text = viewModels[indexPath.row].url.absoluteString
        cell.contentDisplayView.apply(style: .semiboldBodyPrimary)
        cell.contentDisplayView.textAlignment = .left

        cell.backgroundColor = .clear

        return cell
    }
}

extension DAppBrowserTabsViewController: UITableViewDelegate {
    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        60
    }

    func tableView(
        _: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        let tab = viewModels[indexPath.row]

        presenter.selectTab(with: tab.uuid)
    }
}

extension DAppBrowserTabsViewController: DAppBrowserTabsViewProtocol {
    func didReceive(_ viewModels: [DAppBrowserTabModel]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
    }
}
