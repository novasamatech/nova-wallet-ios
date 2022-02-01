import UIKit

final class WalletListViewController: UIViewController, ViewHolder {
    typealias RootViewType = WalletListViewLayout

    let presenter: WalletListPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    private var headerViewModel: WalletListHeaderViewModel?
    private var assetViewModels: [String: [WalletListViewModel]] = [:]
    private var sections: [String] = []

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
        rootView.collectionView.registerCellClass(WalletListTokenCell.self)
        rootView.collectionView.registerCellClass(WalletListTotalBalanceCell.self)
        rootView.collectionView.registerCellClass(WalletListAccountCell.self)
        rootView.collectionView.registerCellClass(WalletListSettingsCell.self)
        rootView.collectionView.registerClass(
            WalletListNetworkView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    @objc func actionSelectAccount() {
        presenter.selectWallet()
    }

    @objc func actionRefresh() {
        presenter.refresh()
    }

    @objc func actionSettings() {}
}

extension WalletListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                return CGSize(width: collectionView.frame.width, height: 56.0)
            } else {
                return CGSize(width: collectionView.frame.width, height: 124.0)
            }
        } else if indexPath.section == 1 {
            return CGSize(width: collectionView.frame.width, height: 56.0)
        } else {
            return CGSize(width: collectionView.frame.width, height: 56.0)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        if section > 1 {
            return CGSize(width: collectionView.frame.width, height: 38.0)
        } else {
            return .zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

extension WalletListViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        2 + sections.count
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return headerViewModel != nil ? 2 : 0
        } else if section == 1 {
            return 1
        } else {
            return assetViewModels[sections[section - 2]]?.count ?? 0
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                let accountCell = collectionView.dequeueReusableCellWithType(
                    WalletListAccountCell.self,
                    for: indexPath
                )!

                if let viewModel = headerViewModel {
                    accountCell.bind(viewModel: viewModel)
                }

                return accountCell

            } else {
                let totalBalanceCell = collectionView.dequeueReusableCellWithType(
                    WalletListTotalBalanceCell.self,
                    for: indexPath
                )!

                totalBalanceCell.amountLabel.text = "1.24343"
                totalBalanceCell.lockedView.detailsLabel.text = "23.434"

                return totalBalanceCell
            }
        } else if indexPath.section == 1 {
            let settingsCell = collectionView.dequeueReusableCellWithType(
                WalletListSettingsCell.self,
                for: indexPath
            )!

            settingsCell.actionButton.addTarget(
                self,
                action: #selector(actionSettings),
                for: .touchUpInside
            )

            return settingsCell
        } else {
            let tokenCell = collectionView.dequeueReusableCellWithType(
                WalletListTokenCell.self,
                for: indexPath
            )!

            if let viewModels = assetViewModels[sections[indexPath.section - 2]] {
                let viewModel = viewModels[indexPath.row]
                tokenCell.bind(viewModel: viewModel)
            }

            return tokenCell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryViewWithType(
            WalletListNetworkView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!

        let title = sections[indexPath.section - 2]

        view.chainView.nameLabel.text = title
        view.valueLabel.text = "$10.23"

        return view
    }
}

extension WalletListViewController: HiddableBarWhenPushed {}

extension WalletListViewController: WalletListViewProtocol {
    func didReceiveHeader(viewModel: WalletListHeaderViewModel) {
        headerViewModel = viewModel

        rootView.collectionView.reloadData()
    }

    func didReceiveAssets(viewModel: [WalletListViewModel]) {
        assetViewModels = viewModel.reduce(
            into: [String: [WalletListViewModel]]()
        ) { result, viewModel in
            var list: [WalletListViewModel] = result[viewModel.networkName] ?? []
            list.append(viewModel)
            result[viewModel.networkName] = list
        }

        sections = Array(assetViewModels.keys.sorted())

        rootView.collectionView.reloadData()
    }

    func didCompleteRefreshing() {
        rootView.collectionView.refreshControl?.endRefreshing()
    }
}
