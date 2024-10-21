import UIKit

final class AssetListCollectionViewDataSource: NSObject {
    var groupsViewModel: AssetListViewModel
    var headerViewModel: AssetListHeaderViewModel?
    var nftViewModel: AssetListNftsViewModel?
    var promotionBannerViewModel: PromotionBannerView.ViewModel?

    var selectedLocale: Locale

    weak var actionsDelegate: AssetListCollectionViewActionsDelegate?
    weak var groupsLayoutDelegate: AssetListCollectionViewLayoutDelegate?

    init(
        groupsViewModel: AssetListViewModel,
        selectedLocale: Locale,
        actionsDelegate: AssetListCollectionViewActionsDelegate? = nil,
        groupsLayoutDelegate: AssetListCollectionViewLayoutDelegate? = nil
    ) {
        self.groupsViewModel = groupsViewModel
        self.selectedLocale = selectedLocale
        self.actionsDelegate = actionsDelegate
        self.groupsLayoutDelegate = groupsLayoutDelegate
    }
}

// MARK: Private

private extension AssetListCollectionViewDataSource {
    func provideAccountCell(
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

    func provideTotalBalanceCell(
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

    func provideSettingsCell(
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

    func provideAssetCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath,
        assetIndex _: Int
    ) -> UICollectionViewCell {
        guard let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) else {
            return UICollectionViewCell()
        }

        return switch groupsViewModel.listState.groups[groupIndex] {
        case let .network(groupViewModel):
            provideNetworkGroupAssetCell(
                collectionView,
                groupViewModel: groupViewModel,
                indexPath: indexPath
            )
        case let .token(groupViewModel):
            provideTokenGroupAssetCell(
                collectionView,
                groupViewModel: groupViewModel,
                indexPath: indexPath
            )
        }
    }

    func provideNetworkGroupAssetCell(
        _ collectionView: UICollectionView,
        groupViewModel: AssetListNetworkGroupViewModel,
        indexPath: IndexPath
    ) -> AssetListAssetCell {
        let assetCell = collectionView.dequeueReusableCellWithType(
            AssetListNetworkGroupAssetCell.self,
            for: indexPath
        )!

        assetCell.bind(viewModel: groupViewModel.assets[indexPath.row])

        return assetCell
    }

    func provideTokenGroupAssetCell(
        _ collectionView: UICollectionView,
        groupViewModel: AssetListTokenGroupViewModel,
        indexPath: IndexPath
    ) -> AssetListAssetCell {
        let expanded = groupsLayoutDelegate?.groupExpanded(
            for: groupViewModel.token.symbol
        ) ?? false

        let assetCell: AssetListAssetCell

        if expanded, indexPath.row != 0 {
            let cell = collectionView.dequeueReusableCellWithType(
                AssetListTokenGroupAssetCell.self,
                for: indexPath
            )!
            cell.bind(viewModel: groupViewModel.assets[indexPath.row - 1])

            assetCell = cell
        } else {
            let cell: AssetListAssetCell = collectionView.dequeueReusableCellWithType(
                AssetListNetworkGroupAssetCell.self,
                for: indexPath
            )!
            cell.bind(viewModel: groupViewModel)

            assetCell = cell
        }

        return assetCell
    }

    func provideEmptyStateCell(
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

    func provideYourNftsCell(
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

    func providePromotionBannerCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListBannerCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListBannerCell.self,
            for: indexPath
        )!

        if let viewModel = promotionBannerViewModel {
            cell.bind(viewModel: viewModel)
        }

        cell.bannerView.delegate = actionsDelegate

        return cell
    }

    func numberOfItemsForAssetGroup(_ section: Int) -> Int {
        if let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(section) {
            switch groupsViewModel.listState.groups[groupIndex] {
            case let .network(groupViewModel):
                return groupViewModel.assets.count
            case let .token(groupViewModel):
                let expanded = groupsLayoutDelegate?.groupExpanded(
                    for: groupViewModel.token.symbol
                ) ?? false

                return expanded
                    ? groupViewModel.assets.count + 1
                    : 1
            }
        } else {
            return 0
        }
    }

    @objc func actionSelectAccount() {
        actionsDelegate?.actionSelectAccount()
    }

    @objc func actionSelectWalletConnect() {
        actionsDelegate?.actionSelectWalletConnect()
    }

    @objc func actionSettings() {
        actionsDelegate?.actionSettings()
    }

    @objc func actionSearch() {
        actionsDelegate?.actionSearch()
    }

    @objc func actionManage() {
        actionsDelegate?.actionManage()
    }

    @objc func actionLocks() {
        actionsDelegate?.actionLocks()
    }

    @objc func actionSend() {
        actionsDelegate?.actionSend()
    }

    @objc func actionReceive() {
        actionsDelegate?.actionReceive()
    }

    @objc func actionBuy() {
        actionsDelegate?.actionBuy()
    }

    @objc func actionSwap() {
        actionsDelegate?.actionSwap()
    }
}

// MARK: UICollectionViewDataSource

extension AssetListCollectionViewDataSource: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        AssetListFlowLayout.SectionType.assetsStartingSection + groupsViewModel.listState.groups.count
    }

    func collectionView(
        _: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        switch AssetListFlowLayout.SectionType(section: section) {
        case .summary:
            headerViewModel != nil ? 2 : 0
        case .nfts:
            nftViewModel != nil ? 1 : 0
        case .promotion:
            promotionBannerViewModel != nil ? 1 : 0
        case .settings:
            groupsViewModel.listState.isEmpty ? 2 : 1
        case .assetGroup:
            numberOfItemsForAssetGroup(section)
        }
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
        case .banner:
            return providePromotionBannerCell(collectionView, indexPath: indexPath)
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
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        // Dequeue the header view
        let view = collectionView.dequeueReusableSupplementaryViewWithType(
            AssetListNetworkView.self,
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )!

        // Configure the header view with the appropriate view model
        if let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(indexPath.section),
           groupsViewModel.listGroupStyle == .networks,
           case let .network(viewModel) = groupsViewModel.listState.groups[groupIndex] {
            view.bind(viewModel: viewModel)
        }

        return view
    }
}
