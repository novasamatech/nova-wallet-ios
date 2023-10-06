import UIKit
import SoraFoundation

final class AssetListViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetListViewLayout

    let presenter: AssetListPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    private var headerViewModel: AssetListHeaderViewModel?
    private var groupsViewModel: AssetListViewModel = .init(isFiltered: false, listState: .list(groups: []))
    private var nftViewModel: AssetListNftsViewModel?

    init(presenter: AssetListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateLoadingState()
    }

    private func setupCollectionView() {
        rootView.collectionView.registerCellClass(AssetListAssetCell.self)
        rootView.collectionView.registerCellClass(AssetListTotalBalanceCell.self)
        rootView.collectionView.registerCellClass(AssetListAccountCell.self)
        rootView.collectionView.registerCellClass(AssetListSettingsCell.self)
        rootView.collectionView.registerCellClass(AssetListEmptyCell.self)
        rootView.collectionView.registerCellClass(AssetListNftsCell.self)
        rootView.collectionView.registerClass(
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        collectionViewLayout?.register(
            TokenGroupDecorationView.self,
            forDecorationViewOfKind: AssetListFlowLayout.assetGroupDecoration
        )

        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    private func updateLoadingState() {
        rootView.collectionView.visibleCells.forEach { updateLoadingState(for: $0) }
    }

    private func updateLoadingState(for cell: UICollectionViewCell) {
        (cell as? AnimationUpdatibleView)?.updateLayerAnimationIfActive()
    }

    @objc private func actionSelectAccount() {
        presenter.selectWallet()
    }

    @objc private func actionSelectWalletConnect() {
        presenter.presentWalletConnect()
    }

    @objc private func actionRefresh() {
        let nftIndexPath = AssetListFlowLayout.CellType.yourNfts.indexPath
        if let nftCell = rootView.collectionView.cellForItem(at: nftIndexPath) as? AssetListNftsCell {
            nftCell.refresh()
        }

        presenter.refresh()
    }

    @objc private func actionSettings() {
        presenter.presentSettings()
    }

    @objc private func actionSearch() {
        presenter.presentSearch()
    }

    @objc private func actionManage() {
        presenter.presentAssetsManage()
    }

    @objc private func actionLocks() {
        presenter.presentLocks()
    }

    @objc private func actionSend() {
        presenter.send()
    }

    @objc private func actionReceive() {
        presenter.receive()
    }

    @objc private func actionBuy() {
        presenter.buy()
    }

    @objc private func actionSwap() {
        presenter.swap()
    }
}

extension AssetListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let cellType = AssetListFlowLayout.CellType(indexPath: indexPath)
        let cellHeight = rootView.collectionViewLayout.cellHeight(for: cellType)
        return CGSize(width: collectionView.bounds.width, height: cellHeight)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        switch AssetListFlowLayout.SectionType(section: section) {
        case .assetGroup:
            return CGSize(
                width: collectionView.frame.width,
                height: AssetListMeasurement.assetHeaderHeight
            )

        case .summary, .settings, .nfts:
            return .zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let cellType = AssetListFlowLayout.CellType(indexPath: indexPath)

        switch cellType {
        case .account, .settings, .emptyState, .totalBalance:
            break
        case .asset:
            if let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(
                indexPath.section
            ) {
                let viewModel = groupsViewModel.listState.groups[groupIndex].assets[indexPath.row]
                presenter.selectAsset(for: viewModel.chainAssetId)
            }
        case .yourNfts:
            presenter.selectNfts()
        }
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        AssetListFlowLayout.SectionType(section: section).cellSpacing
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        AssetListFlowLayout.SectionType(section: section).insets
    }
}

extension AssetListViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        AssetListFlowLayout.SectionType.assetsStartingSection + groupsViewModel.listState.groups.count
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch AssetListFlowLayout.SectionType(section: section) {
        case .summary:
            return headerViewModel != nil ? 2 : 0
        case .nfts:
            return nftViewModel != nil ? 1 : 0
        case .settings:
            return groupsViewModel.listState.isEmpty ? 2 : 1
        case .assetGroup:
            if let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(section) {
                return groupsViewModel.listState.groups[groupIndex].assets.count
            } else {
                return 0
            }
        }
    }

    private func provideAccountCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListAccountCell {
        let accountCell = collectionView.dequeueReusableCellWithType(
            AssetListAccountCell.self,
            for: indexPath
        )!

        if let viewModel = headerViewModel {
            accountCell.bind(viewModel: viewModel)
        }

        accountCell.walletSwitch.addTarget(
            self,
            action: #selector(actionSelectAccount),
            for: .touchUpInside
        )

        accountCell.walletConnect.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(actionSelectWalletConnect)
        ))

        return accountCell
    }

    private func provideTotalBalanceCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListTotalBalanceCell {
        let totalBalanceCell = collectionView.dequeueReusableCellWithType(
            AssetListTotalBalanceCell.self,
            for: indexPath
        )!

        totalBalanceCell.locale = selectedLocale
        totalBalanceCell.locksView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(actionLocks)
        ))
        totalBalanceCell.sendButton.addTarget(
            self,
            action: #selector(actionSend),
            for: .touchUpInside
        )
        totalBalanceCell.receiveButton.addTarget(
            self,
            action: #selector(actionReceive),
            for: .touchUpInside
        )
        totalBalanceCell.buyButton.addTarget(
            self,
            action: #selector(actionBuy),
            for: .touchUpInside
        )
        totalBalanceCell.swapButton.addTarget(
            self,
            action: #selector(actionSwap),
            for: .touchUpInside
        )
        if let viewModel = headerViewModel {
            totalBalanceCell.bind(viewModel: viewModel)
        }

        return totalBalanceCell
    }

    private func provideSettingsCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListSettingsCell {
        let settingsCell = collectionView.dequeueReusableCellWithType(
            AssetListSettingsCell.self,
            for: indexPath
        )!

        settingsCell.locale = selectedLocale

        settingsCell.settingsButton.addTarget(
            self,
            action: #selector(actionSettings),
            for: .touchUpInside
        )
        settingsCell.settingsButton.bind(isFilterOn: groupsViewModel.isFiltered)

        settingsCell.manageButton.addTarget(
            self,
            action: #selector(actionManage),
            for: .touchUpInside
        )

        settingsCell.searchButton.addTarget(
            self,
            action: #selector(actionSearch),
            for: .touchUpInside
        )

        return settingsCell
    }

    private func provideAssetCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath,
        assetIndex: Int
    ) -> AssetListAssetCell {
        let assetCell = collectionView.dequeueReusableCellWithType(
            AssetListAssetCell.self,
            for: indexPath
        )!

        if let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) {
            let viewModel = groupsViewModel.listState.groups[groupIndex].assets[assetIndex]
            assetCell.bind(viewModel: viewModel)
        }

        return assetCell
    }

    private func provideEmptyStateCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListEmptyCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListEmptyCell.self,
            for: indexPath
        )!

        let text = R.string.localizable.walletListEmptyMessage(preferredLanguages: selectedLocale.rLanguages)
        let actionTitle = R.string.localizable.walletListEmptyActionTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        cell.bind(text: text, actionTitle: actionTitle)
        cell.actionButton.addTarget(self, action: #selector(actionBuy), for: .touchUpInside)

        return cell
    }

    private func provideYourNftsCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListNftsCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListNftsCell.self,
            for: indexPath
        )!

        cell.locale = selectedLocale

        if let viewModel = nftViewModel {
            cell.bind(viewModel: viewModel)
        }

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch AssetListFlowLayout.CellType(indexPath: indexPath) {
        case .account:
            return provideAccountCell(collectionView, indexPath: indexPath)
        case .totalBalance:
            return provideTotalBalanceCell(collectionView, indexPath: indexPath)
        case .yourNfts:
            return provideYourNftsCell(collectionView, indexPath: indexPath)
        case .settings:
            return provideSettingsCell(collectionView, indexPath: indexPath)
        case .emptyState:
            return provideEmptyStateCell(collectionView, indexPath: indexPath)
        case let .asset(_, assetIndex):
            return provideAssetCell(collectionView, indexPath: indexPath, assetIndex: assetIndex)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryViewWithType(
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!

        if let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) {
            let viewModel = groupsViewModel.listState.groups[groupIndex]
            view.bind(viewModel: viewModel)
        }

        return view
    }
}

extension AssetListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}

extension AssetListViewController: HiddableBarWhenPushed {}

extension AssetListViewController: AssetListViewProtocol {
    func didReceiveHeader(viewModel: AssetListHeaderViewModel) {
        headerViewModel = viewModel

        rootView.collectionView.reloadData()

        let cellHeight = viewModel.locksAmount == nil ?
            AssetListMeasurement.totalBalanceHeight : AssetListMeasurement.totalBalanceWithLocksHeight

        rootView.collectionViewLayout.updateTotalBalanceHeight(cellHeight)
    }

    func didReceiveGroups(viewModel: AssetListViewModel) {
        groupsViewModel = viewModel

        rootView.collectionView.reloadData()
    }

    func didReceiveNft(viewModel: AssetListNftsViewModel?) {
        nftViewModel = viewModel

        rootView.collectionView.reloadData()
    }

    func didCompleteRefreshing() {
        rootView.collectionView.refreshControl?.endRefreshing()
    }
}
