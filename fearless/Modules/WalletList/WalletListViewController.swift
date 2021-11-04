import UIKit

final class WalletListViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletListViewLayout

    let presenter: WalletListPresenterProtocol

    private var headerViewModel: WalletListHeaderViewModel?
    private var assetViewModels: [WalletListViewModel] = []

    init(presenter: WalletListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(WalletListHeaderCell.self)
        rootView.tableView.registerClassForCell(WalletListAssetCell.self)
    }

    @objc func actionSelectAccount() {
        presenter.selectWallet()
    }
}

extension WalletListViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 76.0
        } else {
            return 88.0
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }

        presenter.selectAsset(at: indexPath.row)
    }
}

extension WalletListViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return headerViewModel != nil ? 1 : 0
        } else {
            return assetViewModels.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let headerCell = tableView.dequeueReusableCellWithType(WalletListHeaderCell.self)!

            if let viewModel = headerViewModel {
                headerCell.bind(viewModel: viewModel)
            }

            headerCell.iconButton.addTarget(
                self,
                action: #selector(actionSelectAccount),
                for: .touchUpInside
            )

            return headerCell
        } else {
            let assetCell = tableView.dequeueReusableCellWithType(WalletListAssetCell.self)!
            assetCell.bind(viewModel: assetViewModels[indexPath.row])
            return assetCell
        }
    }
}

extension WalletListViewController: HiddableBarWhenPushed {}

extension WalletListViewController: WalletListViewProtocol {
    func didReceiveHeader(viewModel: WalletListHeaderViewModel) {
        headerViewModel = viewModel

        rootView.tableView.reloadData()
    }

    func didReceiveAssets(viewModel: [WalletListViewModel]) {
        assetViewModels = viewModel

        rootView.tableView.reloadData()
    }
}
