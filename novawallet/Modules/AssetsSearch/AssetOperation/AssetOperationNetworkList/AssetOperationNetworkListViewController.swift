import UIKit
import Foundation_iOS

final class AssetOperationNetworkListViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetOperationNetworkListViewLayout

    let presenter: AssetOperationNetworkListPresenterProtocol

    private var viewModels: [AssetOperationNetworkViewModel] = []

    init(presenter: AssetOperationNetworkListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetOperationNetworkListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(AssetOperationNetworkListCell.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }
}

// MARK: UITableViewDelegate

extension AssetOperationNetworkListViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)

        let chainAssetId = viewModels[indexPath.section].chainAsset.chainAssetId
        presenter.selectAsset(with: chainAssetId)
    }

    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        Constants.networkCellHeight
    }

    func tableView(
        _: UITableView,
        heightForFooterInSection _: Int
    ) -> CGFloat {
        Constants.sectionInset
    }

    func tableView(
        _: UITableView,
        heightForHeaderInSection section: Int
    ) -> CGFloat {
        guard section == 0 else {
            return .zero
        }

        return Constants.sectionInset
    }
}

// MARK: UITableViewDataSource

extension AssetOperationNetworkListViewController: UITableViewDataSource {
    func tableView(
        _: UITableView,
        numberOfRowsInSection _: Int
    ) -> Int {
        Constants.numberOfRows
    }

    func numberOfSections(in _: UITableView) -> Int {
        viewModels.count
    }

    func tableView(
        _: UITableView,
        viewForFooterInSection _: Int
    ) -> UIView? {
        UIView()
    }

    func tableView(
        _: UITableView,
        viewForHeaderInSection _: Int
    ) -> UIView? {
        UIView()
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(
            AssetOperationNetworkListCell.self,
            forIndexPath: indexPath
        )
        cell.contentDisplayView.bind(viewModel: viewModels[indexPath.section])

        return cell
    }
}

// MARK: AssetOperationNetworkListViewProtocol

extension AssetOperationNetworkListViewController: AssetOperationNetworkListViewProtocol {
    func update(with viewModels: [AssetOperationNetworkViewModel]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
    }

    func updateHeader(with text: String) {
        rootView.headerLabel.text = text
    }
}

// MARK: Constants

private extension AssetOperationNetworkListViewController {
    enum Constants {
        static let titleSection: Int = 0
        static let networksSection: Int = 1
        static let networkCellHeight: CGFloat = 64.0
        static let numberOfSections: Int = 1
        static let sectionInset: CGFloat = 8.0
        static let numberOfRows: Int = 1
    }
}
