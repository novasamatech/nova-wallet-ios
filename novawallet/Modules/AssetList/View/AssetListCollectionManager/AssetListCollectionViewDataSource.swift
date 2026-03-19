import UIKit

final class AssetListCollectionViewDataSource: NSObject {
    weak var view: ControllerBackedProtocol?
    let bannersViewProvider: BannersViewProviderProtocol

    var alertViewModel: InlinableAlertView.Model?
    var groupsViewModel: AssetListViewModel
    var headerViewModel: AssetListHeaderViewModel?
    var organizerViewModel: AssetListOrganizerViewModel?
    var bannersAvailable: Bool?

    var selectedLocale: Locale

    weak var actionsDelegate: AssetListCollectionViewActionsDelegate?
    weak var groupsLayoutDelegate: AssetListCollectionViewLayoutDelegate?

    init(
        view: ControllerBackedProtocol,
        bannersViewProvider: BannersViewProviderProtocol,
        alertViewModel: InlinableAlertView.Model?,
        groupsViewModel: AssetListViewModel,
        selectedLocale: Locale,
        actionsDelegate: AssetListCollectionViewActionsDelegate? = nil,
        groupsLayoutDelegate: AssetListCollectionViewLayoutDelegate? = nil
    ) {
        self.view = view
        self.bannersViewProvider = bannersViewProvider
        self.alertViewModel = alertViewModel
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

    func provideAlertCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let alertViewModel else {
            return collectionView.dequeueReusableCellWithType(
                EmptyCollectionCell.self,
                for: indexPath
            )!
        }

        let alertCell = collectionView.dequeueReusableCellWithType(
            InlinableAlertCollectionViewCell.self,
            for: indexPath
        )!

        alertCell.contentInsets = .init(
            verticalInset: .zero,
            horizontalInset: UIConstants.horizontalInset
        )
        alertCell.view.fillColor = R.color.colorBlockBackground()!

        alertCell.view.bind(alertViewModel)

        alertCell.view.learnMoreAction = { [weak self] alertType in
            self?.actionsDelegate?.actionAlertLearnMore(alertType)
        }

        return alertCell
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

        let totalBalanceView = totalBalanceCell.totalView

        totalBalanceView.privacyToggleButton.addTarget(
            self,
            action: #selector(actionTogglePrivacy),
            for: .touchUpInside
        )

        totalBalanceView.locksView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(actionLocks)
        ))
        totalBalanceView.sendButton.addTarget(
            self,
            action: #selector(actionSend),
            for: .touchUpInside
        )
        totalBalanceView.receiveButton.addTarget(
            self,
            action: #selector(actionReceive),
            for: .touchUpInside
        )
        totalBalanceView.buySellButton.addTarget(
            self,
            action: #selector(actionBuySell),
            for: .touchUpInside
        )
        totalBalanceView.swapButton.addTarget(
            self,
            action: #selector(actionSwap),
            for: .touchUpInside
        )
        totalBalanceView.giftButton.addTarget(
            self,
            action: #selector(actionGift),
            for: .touchUpInside
        )

        let cardView = totalBalanceCell.cardView

        cardView.addTarget(
            self,
            action: #selector(actionCardOpen),
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

        settingsCell.styleSwitcher.controlContentView.setup(with: .init(using: groupsViewModel.listGroupStyle))

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
        settingsCell.styleSwitcher.addTarget(
            self,
            action: #selector(actionSwitchStyle),
            for: .valueChanged
        )

        settingsCell.manageButton.bind(showingBadge: groupsViewModel.isFiltered)

        return settingsCell
    }

    func provideAssetCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(
            indexPath.section
        ) else {
            return collectionView.dequeueReusableCellWithType(
                EmptyCollectionCell.self,
                for: indexPath
            )!
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

            if expanded {
                cell.showDivider()
            }

            assetCell = cell
        }

        assetCell.configureSelectionView(for: expanded)

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

        let text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.walletListEmptyMessage()
        let actionTitle = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.walletListEmptyActionTitle()

        cell.bind(text: text, actionTitle: actionTitle)
        cell.actionButton.addTarget(self, action: #selector(actionBuySell), for: .touchUpInside)

        return cell
    }

    func provideOrganizerCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let itemIndex = indexPath.item

        guard let organizerViewModel, organizerViewModel.items.count > itemIndex else {
            return collectionView.dequeueReusableCellWithType(
                EmptyCollectionCell.self,
                for: indexPath
            )!
        }

        let addsSeparator = organizerViewModel.items.count > 1 &&
            itemIndex < organizerViewModel.items.endIndex - 1

        let organizerItemModel = organizerViewModel.items[itemIndex]

        return switch organizerItemModel {
        case let .nfts(nftsModel):
            provideYourNftsCell(
                collectionView,
                indexPath: indexPath,
                model: nftsModel,
                addsSeparator: addsSeparator
            )
        case let .pendingTransactions(transactionsModel):
            provideTransactionsToSignCell(
                collectionView,
                indexPath: indexPath,
                model: transactionsModel,
                addsSeparator: addsSeparator
            )
        }
    }

    func provideYourNftsCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath,
        model: SecuredViewModel<AssetListNftsViewModel>,
        addsSeparator: Bool
    ) -> AssetListNftsCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListNftsCell.self,
            for: indexPath
        )!

        cell.locale = selectedLocale
        cell.bind(viewModel: model)

        if addsSeparator {
            cell.addSeparatorLine(horizontalSpace: UIConstants.horizontalInset * 2)
        }

        return cell
    }

    func provideTransactionsToSignCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath,
        model: AssetListMultisigOperationsViewModel,
        addsSeparator: Bool
    ) -> AssetListMultisigOperationsCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListMultisigOperationsCell.self,
            for: indexPath
        )!

        cell.locale = selectedLocale
        cell.bind(viewModel: model)

        if addsSeparator {
            cell.addSeparatorLine(horizontalSpace: UIConstants.horizontalInset * 2)
        }

        return cell
    }

    func provideBannersCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> BannersContainerCollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(
            BannersContainerCollectionViewCell.self,
            for: indexPath
        )!

        bannersViewProvider.setupBanners(
            on: view,
            view: cell.view
        )

        cell.contentInsets.left = UIConstants.horizontalInset
        cell.contentInsets.right = UIConstants.horizontalInset

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

    @objc func actionBuySell() {
        actionsDelegate?.actionBuySell()
    }

    @objc func actionSwap() {
        actionsDelegate?.actionSwap()
    }

    @objc func actionGift() {
        actionsDelegate?.actionGift()
    }

    @objc func actionSwitchStyle() {
        actionsDelegate?.actionChangeAssetListStyle()
    }

    @objc func actionCardOpen() {
        actionsDelegate?.actionCardOpen()
    }

    @objc func actionRefresh() {
        actionsDelegate?.actionRefresh()
    }

    @objc func actionTogglePrivacy() {
        actionsDelegate?.actionTogglePrivacy()
    }

    @objc func actionLoadMore() {
        actionsDelegate?.actionLoadMore()
    }

    var loadMoreSectionIndex: Int? {
        guard groupsViewModel.showsLoadMore else { return nil }
        return AssetListFlowLayout.SectionType.assetsStartingSection + groupsViewModel.listState.groups.count
    }

    func provideLoadMoreCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> AssetListLoadMoreCell {
        let cell = collectionView.dequeueReusableCellWithType(
            AssetListLoadMoreCell.self,
            for: indexPath
        )!

        let languages = selectedLocale.rLanguages
        let title: String = switch groupsViewModel.listGroupStyle {
        case .tokens:
            R.string(preferredLanguages: languages).localizable.assetListLoadMoreTokens()
        case .networks:
            R.string(preferredLanguages: languages).localizable.assetListLoadMoreNetworks()
        }

        cell.bind(title: title)
        cell.actionButton.removeTarget(nil, action: nil, for: .touchUpInside)
        cell.actionButton.addTarget(
            self,
            action: #selector(actionLoadMore),
            for: .touchUpInside
        )

        return cell
    }
}

// MARK: UICollectionViewDataSource

extension AssetListCollectionViewDataSource: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        let baseSections = AssetListFlowLayout.SectionType.assetsStartingSection + groupsViewModel.listState.groups.count
        return groupsViewModel.showsLoadMore ? baseSections + 1 : baseSections
    }

    func collectionView(
        _: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        if section == loadMoreSectionIndex {
            return 1
        }

        switch AssetListFlowLayout.SectionType(section: section) {
        case .summary:
            var itemsCount = 0

            if alertViewModel != nil { itemsCount += 1 }
            if headerViewModel != nil { itemsCount += 2 }

            return itemsCount
        case .organizer:
            return organizerViewModel?.items.count ?? 0
        case .banners:
            return bannersAvailable == true ? 1 : 0
        case .settings:
            return groupsViewModel.listState.isEmpty ? 2 : 1
        case .assetGroup:
            return numberOfItemsForAssetGroup(section)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch AssetListFlowLayout.CellType(
            indexPath: indexPath,
            in: collectionView,
            loadMoreSection: loadMoreSectionIndex
        ) {
        case .account:
            provideAccountCell(collectionView, indexPath: indexPath)
        case .alert:
            provideAlertCell(collectionView, indexPath: indexPath)
        case .totalBalance:
            provideTotalBalanceCell(collectionView, indexPath: indexPath)
        case .organizerItem:
            provideOrganizerCell(collectionView, indexPath: indexPath)
        case .banner:
            provideBannersCell(collectionView, indexPath: indexPath)
        case .settings:
            provideSettingsCell(collectionView, indexPath: indexPath)
        case .emptyState:
            provideEmptyStateCell(collectionView, indexPath: indexPath)
        case .asset:
            provideAssetCell(collectionView, indexPath: indexPath)
        case .loadMore:
            provideLoadMoreCell(collectionView, indexPath: indexPath)
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

        // Do not configure for load more section
        guard indexPath.section != loadMoreSectionIndex else {
            return view
        }

        // Configure the header view with the appropriate view model
        if let groupIndex = AssetListFlowLayout.SectionType.assetsGroupIndexFromSection(indexPath.section),
           groupsViewModel.listGroupStyle == .networks,
           case let .network(viewModel) = groupsViewModel.listState.groups[groupIndex] {
            view.bind(viewModel: viewModel)
        }

        return view
    }
}
