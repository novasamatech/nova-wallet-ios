import UIKit

final class CommonDelegationTracksViewController: UIViewController, ViewHolder {
    typealias RootViewType = CommonDelegationTracksViewLayout

    let presenter: CommonDelegationTracksPresenterProtocol
    private var viewModels: [TrackTableViewCell.Model] = []

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
        rootView.tableView.dataSource = self
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
}

extension CommonDelegationTracksViewController {
    static func estimatePreferredHeight(for tracks: [TrackVote]) -> CGFloat {
        RootViewType.estimatePreferredHeight(for: tracks)
    }
}
