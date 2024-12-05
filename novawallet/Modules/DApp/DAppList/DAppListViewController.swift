import UIKit
import SoraFoundation
import SubstrateSdk

private typealias DataSource = UICollectionViewDiffableDataSource<DAppListSection, DAppListItem>

final class DAppListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol

    var loadingView: DAppListLoadingView? {
        guard case .loading = state else {
            return nil
        }

        return nil
    }

    private lazy var dataSource = createDataSource()

    private var sectionViewModels: [DAppListSectionViewModel] = []
    private var walletSwitchViewModel: WalletSwitchViewModel?

    private var state: DAppListState?

    init(
        presenter: DAppListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureCollectionView()

        presenter.setup()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        loadingView?.didDisappearSkeleton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        loadingView?.didAppearSkeleton()
    }
}

// MARK: Private

private extension DAppListViewController {
    func configureCollectionView() {
        rootView.collectionView.registerCellClass(DAppListHeaderView.self)
        rootView.collectionView.registerCellClass(DAppCategoriesViewCell.self)
        rootView.collectionView.registerCellClass(DAppListErrorView.self)
        rootView.collectionView.registerCellClass(DAppItemCollectionViewCell.self)

        rootView.collectionView.registerClass(
            RoundedIconTitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        rootView.collectionView.registerClass(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self

        rootView.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    func setupHeaderView(
        using collectionView: UICollectionView,
        walletSwitchViewModel: WalletSwitchViewModel,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppListHeaderView = collectionView.dequeueReusableCellWithType(
            DAppListHeaderView.self,
            for: indexPath
        )!

        view.walletSwitch.bind(viewModel: walletSwitchViewModel)

        view.walletSwitch.addTarget(self, action: #selector(actionSelectAccount), for: .touchUpInside)
        view.searchView.addTarget(self, action: #selector(actionSearch), for: .touchUpInside)

        view.selectedLocale = selectedLocale

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
        cell.view.bind(categories: categoriess)

        return cell
    }

    func setupDAppView(
        using collectionView: UICollectionView,
        dApp: DAppViewModel,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell: DAppItemCollectionViewCell = collectionView.dequeueReusableCellWithType(
            DAppItemCollectionViewCell.self,
            for: indexPath
        )!

        if dApp.isFavorite {
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

        var viewModel: TitleCollectionHeaderView.Model

        switch sectionViewModels[indexPath.section] {
        case .favorites:
            viewModel = .init(
                title: title,
                icon: R.image.iconFavButtonSel()
            )
        case let .category(model):
            viewModel = .init(
                title: title,
                icon: nil
            )
        default:
            return nil
        }

        let header: TitleCollectionHeaderView? = collectionView.dequeueReusableSupplementaryView(
            forSupplementaryViewOfKind: kind,
            for: indexPath
        )
        header?.contentInsets.top = 4
        header?.contentInsets.bottom = 4
        header?.bind(viewModel: viewModel)

        return header
    }

    func setupLoadingView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view = collectionView.dequeueReusableCellWithType(DAppListLoadingView.self, for: indexPath)!
        view.selectedLocale = selectedLocale

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

    func setupLoadingOrErrorView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        switch state {
        case .error:
            return setupErrorView(using: collectionView, indexPath: indexPath)
        case .loading:
            return setupLoadingView(using: collectionView, indexPath: indexPath)
        case .loaded, .none:
            return UICollectionViewCell()
        }
    }

    func updateIcon(for headerView: DAppListHeaderView, walletSwitchViewModel: WalletSwitchViewModel) {
        headerView.walletSwitch.bind(viewModel: walletSwitchViewModel)
    }
}

// MARK: Data Source

private extension DAppListViewController {
    func createDataSource() -> DataSource {
        let cellProvider = cellProvider()

        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: cellProvider
        )
        dataSource.supplementaryViewProvider = supplementaryViewProvider()

        return dataSource
    }

    func cellProvider() -> DataSource.CellProvider {
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
            case let .favorites(model, _):
                setupDAppView(
                    using: collectionView,
                    dApp: model,
                    indexPath: indexPath
                )
            case let .category(model, _):
                setupDAppView(
                    using: collectionView,
                    dApp: model,
                    indexPath: indexPath
                )
            }
        }
    }

    func supplementaryViewProvider() -> DataSource.SupplementaryViewProvider {
        { [weak self] collectionView, kind, indexPath in
            self?.setupSectionHeaderView(
                using: collectionView,
                kind: kind,
                indexPath: indexPath
            )
        }
    }
}

// MARK: Actions

private extension DAppListViewController {
    @objc func actionSelectAccount() {
        presenter.activateAccount()
    }

    @objc func actionSearch() {
        presenter.activateSearch()
    }

    @objc func actionRefresh() {
        presenter.refresh()
    }

    @objc func actionSettings() {
        presenter.activateSettings()
    }
}

// MARK: UICollectionViewDelegate

extension DAppListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: ErrorStateViewDelegate

extension DAppListViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.refresh()
    }
}

// MARK: DAppCategoriesViewDelegate

extension DAppListViewController: DAppCategoriesViewDelegate {
    func dAppCategories(
        view _: DAppCategoriesView,
        didSelectCategoryWith identifier: String?
    ) {
        guard let identifier else { return }

        presenter.selectCategory(with: identifier)
    }
}

// MARK: DAppListViewProtocol

extension DAppListViewController: DAppListViewProtocol {
    func didReceive(_ sections: [DAppListSectionViewModel]) {
        rootView.sectionViewModels = sections
        sectionViewModels = sections

        dataSource.apply(sections.models)
    }

    func didReceive(state: DAppListState) {
        self.state = state

        // rootView.collectionView.reloadData()
    }

    func didCompleteRefreshing() {
        rootView.collectionView.refreshControl?.endRefreshing()
    }
}

// MARK: Localizable

extension DAppListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}

// MARK: HiddableBarWhenPushed

extension DAppListViewController: HiddableBarWhenPushed {}
