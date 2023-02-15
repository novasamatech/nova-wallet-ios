import UIKit

final class CommonDelegationTracksViewController: UIViewController, ViewHolder {
    typealias RootViewType = CommonDelegationTracksViewLayout

    let presenter: CommonDelegationTracksPresenterProtocol
    private var viewModels: [TrackTableViewCell.Model] = []
    private var titleModel: String = ""

    init(presenter: CommonDelegationTracksPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CommonDelegationTracksViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(TrackTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }
}

extension CommonDelegationTracksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        let headerView: IconTitleHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.titleView.detailsLabel.apply(style: .bottomSheetTitle)
        headerView.contentInsets = .init(top: 10, left: 0, bottom: 10, right: 0)
        headerView.titleView.bind(viewModel: .init(title: titleModel, icon: nil))
        return headerView
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        CommonDelegationTracksViewLayout.Constants.cellHeight
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CommonDelegationTracksViewLayout.Constants.titleHeight
    }
}

extension CommonDelegationTracksViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TrackTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let cellModel = viewModels[indexPath.row]
        cell.bind(viewModel: cellModel)
        return cell
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }
}

extension CommonDelegationTracksViewController: CommonDelegationTracksViewProtocol {
    func didReceive(tracks: [TrackTableViewCell.Model]) {
        viewModels = tracks
        rootView.tableView.reloadData()
    }

    func didReceive(title: String) {
        titleModel = title
        rootView.tableView.reloadData()
    }
}

extension CommonDelegationTracksViewController {
    static func estimatePreferredHeight(for tracks: [GovernanceTrackInfoLocal]) -> CGFloat {
        RootViewType.estimatePreferredHeight(for: tracks)
    }
}
