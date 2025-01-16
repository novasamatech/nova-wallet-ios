import UIKit

extension DAppListViewController {
    func createDataSource() -> DAppListCollectionDataSource {
        let cellProvider = cellProvider()

        let dataSource = DAppListCollectionDataSource(
            collectionView: rootView.collectionView,
            cellProvider: cellProvider
        )
        dataSource.supplementaryViewProvider = supplementaryViewProvider()

        return dataSource
    }

    func cellProvider() -> DAppListCollectionDataSource.CellProvider {
        { [weak self] collectionView, indexPath, model -> UICollectionViewCell? in
            guard let self else { return nil }

            return switch model {
            case let .header(model):
                setupHeaderView(
                    using: collectionView,
                    walletSwitchViewModel: model,
                    indexPath: indexPath
                )
            case let .categorySelect(models):
                setupCategoriesView(
                    using: collectionView,
                    categoriess: models,
                    indexPath: indexPath
                )
            case let .banner(model):
                setupBannerView(
                    using: collectionView,
                    banner: model,
                    indexPath: indexPath
                )
            case let .favorites(model, _):
                setupDAppView(
                    using: collectionView,
                    dApp: model,
                    indexPath: indexPath,
                    favorite: true
                )
            case let .category(model, _):
                setupDAppView(
                    using: collectionView,
                    dApp: model,
                    indexPath: indexPath,
                    favorite: false
                )
            case .notLoaded:
                setupLoadingView(
                    using: collectionView,
                    indexPath: indexPath
                )
            case .error:
                setupErrorView(
                    using: collectionView,
                    indexPath: indexPath
                )
            }
        }
    }

    func supplementaryViewProvider() -> DAppListCollectionDataSource.SupplementaryViewProvider {
        { [weak self] collectionView, kind, indexPath in
            self?.setupSectionHeaderView(
                using: collectionView,
                kind: kind,
                indexPath: indexPath
            )
        }
    }
}

// MARK: Private

private extension DAppListViewController {
    func setupHeaderView(
        using collectionView: UICollectionView,
        walletSwitchViewModel: WalletSwitchViewModel,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppListHeaderView = collectionView.dequeueReusableCellWithType(
            DAppListHeaderView.self,
            for: indexPath
        )!

        view.selectedLocale = selectedLocale
        view.walletSwitch.bind(viewModel: walletSwitchViewModel)

        view.walletSwitch.addTarget(
            self,
            action: #selector(actionSelectAccount),
            for: .touchUpInside
        )
        view.searchView.addTarget(
            self,
            action: #selector(actionSearch),
            for: .touchUpInside
        )
        view.settingsButton.addTarget(
            self,
            action: #selector(actionSettings),
            for: .touchUpInside
        )

        return view
    }

    func setupCategoriesView(
        using collectionView: UICollectionView,
        categoriess: [DAppCategoryViewModel],
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell: DAppCategoriesViewCell = collectionView.dequeueReusableCellWithType(
            DAppCategoriesViewCell.self,
            for: indexPath
        )!

        cell.view.delegate = self
        cell.view.chagesStateOnSelect = false
        cell.view.bind(categories: categoriess)

        return cell
    }

    func setupBannerView(
        using collectionView: UICollectionView,
        banner: DAppListBannerViewModel,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell: DAppListBannerView = collectionView.dequeueReusableCellWithType(
            DAppListBannerView.self,
            for: indexPath
        )!

        cell.bind(viewModel: banner)

        return cell
    }

    func setupDAppView(
        using collectionView: UICollectionView,
        dApp: DAppViewModel,
        indexPath: IndexPath,
        favorite: Bool
    ) -> UICollectionViewCell {
        let cell: DAppItemCollectionViewCell = collectionView.dequeueReusableCellWithType(
            DAppItemCollectionViewCell.self,
            for: indexPath
        )!

        if favorite {
            cell.view.layoutStyle = .vertical
        } else {
            cell.view.layoutStyle = .horizontal
        }

        cell.view.bind(viewModel: dApp)

        return cell
    }

    func setupSectionHeaderView(
        using collectionView: UICollectionView,
        kind: String,
        indexPath: IndexPath
    ) -> UICollectionReusableView? {
        guard let title = dataSource.snapshot().sectionIdentifiers[indexPath.section].title else {
            return nil
        }

        let header: TitleCollectionHeaderView? = collectionView.dequeueReusableSupplementaryView(
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )
        header?.contentInsets.top = 4
        header?.contentInsets.bottom = 4

        var viewModel: TitleCollectionHeaderView.Model

        switch sectionViewModels[indexPath.section] {
        case .favorites:
            viewModel = .init(
                title: title,
                icon: R.image.iconFavButtonSel()
            )
            header?.button.imageWithTitleView?.title = R.string.localizable.commonSeeAll(
                preferredLanguages: selectedLocale.rLanguages
            )

            header?.apply(style: .titleWithButton)
            header?.button.addTarget(
                self,
                action: #selector(actionSeeAllFavorites),
                for: .touchUpInside
            )
        case .category:
            viewModel = .init(
                title: title,
                icon: nil
            )
            header?.apply(style: .title)
        default:
            return nil
        }

        header?.bind(viewModel: viewModel)

        return header
    }

    func setupLoadingView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view = collectionView.dequeueReusableCellWithType(
            DAppListLoadingView.self,
            for: indexPath
        )!

        return view
    }

    func setupErrorView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view = collectionView.dequeueReusableCellWithType(DAppListErrorView.self, for: indexPath)!
        view.selectedLocale = selectedLocale

        view.errorView.delegate = self

        return view
    }
}
