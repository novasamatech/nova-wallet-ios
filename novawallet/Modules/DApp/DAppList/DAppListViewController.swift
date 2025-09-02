import UIKit
import Foundation_iOS
import SubstrateSdk

typealias DAppListCollectionDataSource = UICollectionViewDiffableDataSource<DAppListSection, DAppListItem>

final class DAppListViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppListViewLayout

    let presenter: DAppListPresenterProtocol
    let bannersViewProvider: BannersViewProviderProtocol

    var loadingView: DAppListLoadingView? {
        guard sectionViewModels.loaded else {
            return nil
        }

        return rootView.collectionView.cellForItem(
            at: IndexPath(item: 0, section: 0)
        ) as? DAppListLoadingView
    }

    lazy var dataSource = createDataSource()

    var sectionViewModels: [DAppListSectionViewModel] = []
    var walletSwitchViewModel: WalletSwitchViewModel?

    init(
        presenter: DAppListPresenterProtocol,
        bannersViewProvider: BannersViewProviderProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.bannersViewProvider = bannersViewProvider

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

        setupView()

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
    func setupView() {
        rootView.delegate = self

        setupCollectionView()
    }

    func setupCollectionView() {
        rootView.collectionView.registerCellClass(DAppListHeaderView.self)
        rootView.collectionView.registerCellClass(DAppCategoriesViewCell.self)
        rootView.collectionView.registerCellClass(BannersContainerCollectionViewCell.self)
        rootView.collectionView.registerCellClass(DAppListErrorView.self)
        rootView.collectionView.registerCellClass(DAppItemCollectionViewCell.self)
        rootView.collectionView.registerCellClass(DAppListLoadingView.self)

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

    func updateIcon(for headerView: DAppListHeaderView, walletSwitchViewModel: WalletSwitchViewModel) {
        headerView.walletSwitch.bind(viewModel: walletSwitchViewModel)
    }
}

// MARK: Actions

extension DAppListViewController {
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

    @objc func actionSeeAllFavorites() {
        presenter.seeAllFavorites()
    }

    func selectDApp(
        section: DAppListSection,
        at index: Int
    ) {
        let item = section.cells[index]

        switch item {
        case let .category(model, _),
             let .favorites(model, _):
            presenter.selectDApp(with: model.identifier)
        default:
            break
        }
    }
}

// MARK: DAppListViewLayoutDelegate

extension DAppListViewController: DAppListViewLayoutDelegate {
    func heightForBannerSection() -> CGFloat {
        bannersViewProvider.getMaxBannerHeight()
    }
}

// MARK: UICollectionViewDelegate

extension DAppListViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let section = sectionViewModels[indexPath.section]

        switch section {
        case let .category(model),
             let .favorites(model):
            selectDApp(section: model, at: indexPath.row)
        default:
            break
        }
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
