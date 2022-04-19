import UIKit
import SoraFoundation
import SubstrateSdk

final class DAppListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol

    var collectionViewLayout: UICollectionViewFlowLayout? {
        rootView.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }

    var loadingView: DAppListLoadingView? {
        guard case .loading = state else {
            return nil
        }

        return rootView.collectionView.cellForItem(
            at: DAppListFlowLayout.CellType.notLoaded.indexPath
        ) as? DAppListLoadingView
    }

    init(presenter: DAppListPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    private var accountIcon: UIImage?

    private var state: DAppListState?

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

    private func configureCollectionView() {
        rootView.collectionView.registerCellClass(DAppListHeaderView.self)
        rootView.collectionView.registerCellClass(DAppListLoadingView.self)
        rootView.collectionView.registerCellClass(DAppCategoriesView.self)
        rootView.collectionView.registerCellClass(DAppListErrorView.self)
        rootView.collectionView.registerCellClass(DAppItemView.self)
        rootView.collectionView.registerCellClass(DAppListFeaturedHeaderView.self)

        collectionViewLayout?.register(
            DAppListDecorationView.self,
            forDecorationViewOfKind: DAppListFlowLayout.backgroundDecoration
        )

        collectionViewLayout?.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    private func updateIcon(for headerView: DAppListHeaderView, icon _: UIImage?) {
        headerView.accountButton.imageWithTitleView?.iconImage = accountIcon
        headerView.accountButton.invalidateLayout()
    }

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

extension DAppListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let cellType = DAppListFlowLayout.CellType(indexPath: indexPath) else {
            return
        }

        switch cellType {
        case .header, .notLoaded, .dAppHeader, .categories:
            break
        case let .dapp(index):
            presenter.selectDApp(at: index)
        }
    }
}

extension DAppListViewController: UICollectionViewDataSource {
    private func setupHeaderView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppListHeaderView = collectionView.dequeueReusableCellWithType(
            DAppListHeaderView.self,
            for: indexPath
        )!

        updateIcon(for: view, icon: accountIcon)

        view.accountButton.addTarget(self, action: #selector(actionSelectAccount), for: .touchUpInside)
        view.searchView.addTarget(self, action: #selector(actionSearch), for: .touchUpInside)

        view.selectedLocale = selectedLocale

        return view
    }

    private func setupCategoriesView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppCategoriesView = collectionView.dequeueReusableCellWithType(
            DAppCategoriesView.self,
            for: indexPath
        )!

        view.delegate = self

        let numberOfCategories = presenter.numberOfCategories()
        let allCategories = (0 ..< numberOfCategories).map { presenter.category(at: $0) }

        view.bind(categories: allCategories)

        view.setSelectedIndex(presenter.selectedCategoryIndex(), animated: false)

        return view
    }

    private func setupDAppView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view: DAppItemView = collectionView.dequeueReusableCellWithType(DAppItemView.self, for: indexPath)!
        view.delegate = self

        let dApp = presenter.dApp(at: indexPath.row - 1)
        view.bind(viewModel: dApp)

        return view
    }

    private func setupDAppHeaderView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(DAppListFeaturedHeaderView.self, for: indexPath)!
        cell.locale = selectedLocale

        cell.actionButton.addTarget(self, action: #selector(actionSettings), for: .touchUpInside)

        return cell
    }

    private func setupLoadingView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view = collectionView.dequeueReusableCellWithType(DAppListLoadingView.self, for: indexPath)!
        view.selectedLocale = selectedLocale

        return view
    }

    private func setupErrorView(
        using collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        let view = collectionView.dequeueReusableCellWithType(DAppListErrorView.self, for: indexPath)!
        view.selectedLocale = selectedLocale

        view.errorView.delegate = self

        return view
    }

    private func setupLoadingOrErrorView(
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

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cellType = DAppListFlowLayout.CellType(indexPath: indexPath) else {
            return UICollectionViewCell()
        }

        switch cellType {
        case .header:
            return setupHeaderView(using: collectionView, indexPath: indexPath)
        case .notLoaded:
            return setupLoadingOrErrorView(using: collectionView, indexPath: indexPath)
        case .dAppHeader:
            return setupDAppHeaderView(using: collectionView, indexPath: indexPath)
        case .categories:
            return setupCategoriesView(using: collectionView, indexPath: indexPath)
        case .dapp:
            return setupDAppView(using: collectionView, indexPath: indexPath)
        }
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        switch state {
        case .error, .loading:
            return 1
        case .loaded:
            return 2
        case .none:
            return 0
        }
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == DAppListFlowLayout.CellType.header.indexPath.section {
            switch state {
            case .error, .loading:
                return 3
            case .loaded:
                return 2
            case .none:
                return 0
            }
        } else {
            return presenter.numberOfDApps() + 1
        }
    }
}

extension DAppListViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.refresh()
    }
}

extension DAppListViewController: DAppCategoriesViewDelegate {
    func dAppCategories(view _: DAppCategoriesView, didSelectItemAt index: Int) {
        presenter.selectCategory(at: index)
    }
}

extension DAppListViewController: DAppListViewProtocol {
    func didReceiveAccount(icon: DrawableIcon) {
        let iconSize = CGSize(
            width: UIConstants.navigationAccountIconSize,
            height: UIConstants.navigationAccountIconSize
        )

        accountIcon = icon.imageWithFillColor(.clear, size: iconSize, contentScale: UIScreen.main.scale)

        if let headerView = rootView.findHeaderView() {
            updateIcon(for: headerView, icon: accountIcon)
        }
    }

    func didReceive(state: DAppListState) {
        self.state = state

        rootView.collectionView.reloadData()
    }

    func didCompleteRefreshing() {
        rootView.collectionView.refreshControl?.endRefreshing()
    }
}

extension DAppListViewController: DAppItemViewDelegate {
    func dAppItemDidToggleFavorite(_ view: DAppItemView) {
        guard
            let indexPath = rootView.collectionView.indexPath(for: view),
            let cellType = DAppListFlowLayout.CellType(indexPath: indexPath) else {
            return
        }

        switch cellType {
        case .header, .notLoaded, .dAppHeader, .categories:
            break
        case let .dapp(index):
            presenter.toogleFavoriteForDApp(at: index)
        }
    }
}

extension DAppListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            rootView.collectionView.reloadData()
        }
    }
}

extension DAppListViewController: HiddableBarWhenPushed {}
