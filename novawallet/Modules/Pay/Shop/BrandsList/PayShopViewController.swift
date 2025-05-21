import UIKit
import Foundation_iOS
import UIKit_iOS

final class PayShopViewController: UIViewController, ViewHolder, AdaptiveDesignable {
    typealias RootViewType = PayShopViewLayout

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    enum Section: Int, CaseIterable {
        case availability
        case purchases
        case recommended
        case brands
        case loadMore
    }

    enum Item: Hashable {
        case availability(PayShopAvailabilityViewModel)
        case purchases(Int)
        case recommended(PayShopRecommendedViewModel)
        case brand(PayShopBrandViewModel)
        case brandSkeleton(Int)
        case loadMore
    }

    let presenter: PayShopPresenterProtocol

    private lazy var dataSource = createDataSource()

    private var skeletonItemsCount: Int {
        let baseCount: Int = 6 // Base number of skeleton cells for standard screen size
        return Int(ceil(Double(baseCount) * designScaleRatio.height))
    }

    weak var scrollViewTracker: ScrollViewTrackingProtocol?

    private var hasLoadMore: Bool = false

    init(presenter: PayShopPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PayShopViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()

        presenter.setup()
    }
}

private extension PayShopViewController {
    func setupCollectionView() {
        rootView.collectionView.registerCellClass(PayShopAvailabilityCell.self)
        rootView.collectionView.registerCellClass(PayShopBrandCell.self)
        rootView.collectionView.registerCellClass(PayShopSkeletonBrandCell.self)
        rootView.collectionView.registerCellClass(PayShopLoadMoreCell.self)
        rootView.collectionView.registerClass(
            PayShopSearchHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        rootView.collectionView.dataSource = dataSource
        rootView.collectionView.delegate = self

        setupInitialDataSource()
    }

    func createDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: rootView.collectionView,
            cellProvider: { [weak self] collectionView, indexPath, model -> UICollectionViewCell? in
                guard let self else {
                    return nil
                }

                return self.setupCell(of: collectionView, model: model, indexPath: indexPath)
            }
        )

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else {
                return nil
            }

            let section = self.dataSource.snapshot().sectionIdentifiers[indexPath.section]

            return self.setupHeader(of: collectionView, model: section, kind: kind, indexPath: indexPath)
        }

        return dataSource
    }

    func setupCell(of collectionView: UICollectionView, model: Item, indexPath: IndexPath) -> UICollectionViewCell {
        switch model {
        case let .availability(viewModel):
            let cell = collectionView.dequeueReusableCellWithType(PayShopAvailabilityCell.self, for: indexPath)!
            cell.view.locale = selectedLocale

            cell.view.bind(viewModel: viewModel)
            return cell
        case .purchases:
            // TODO: Implement in the separate task
            return UICollectionViewCell()
        case .recommended:
            // TODO: Implement in the separate task
            return UICollectionViewCell()
        case let .brand(viewModel):
            let cell = collectionView.dequeueReusableCellWithType(PayShopBrandCell.self, for: indexPath)!
            cell.bind(viewModel: viewModel, locale: selectedLocale)
            return cell
        case .brandSkeleton:
            let cell = collectionView.dequeueReusableCellWithType(PayShopSkeletonBrandCell.self, for: indexPath)!
            return cell
        case .loadMore:
            let cell = collectionView.dequeueReusableCellWithType(PayShopLoadMoreCell.self, for: indexPath)!
            cell.view.locale = selectedLocale

            return cell
        }
    }

    func setupHeader(
        of collectionView: UICollectionView,
        model: Section,
        kind: String,
        indexPath: IndexPath
    ) -> UICollectionReusableView {
        switch model {
        case .brands:
            let view = collectionView.dequeueReusableSupplementaryViewWithType(
                PayShopSearchHeaderView.self,
                forSupplementaryViewOfKind: kind,
                for: indexPath
            )!

            view.locale = selectedLocale

            view.searchButton.addTarget(self, action: #selector(actionSearch), for: .touchUpInside)

            return view
        default:
            return UICollectionReusableView()
        }
    }

    func setupInitialDataSource() {
        var snapshot = Snapshot()

        snapshot.appendSections([.availability, .brands, .loadMore])
        snapshot.appendItems([.availability(.available(.loading))], toSection: .availability)

        let skeletonItems = (0 ..< skeletonItemsCount).map { Item.brandSkeleton($0) }
        snapshot.appendItems(skeletonItems, toSection: .brands)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func updateLoadMoreCell(in snapshot: inout Snapshot, hasMore: Bool) {
        let hadLoadMore = hasLoadMore

        hasLoadMore = hasMore

        if hasMore, !hadLoadMore {
            snapshot.appendItems([.loadMore], toSection: .loadMore)
        } else if !hasMore, hadLoadMore {
            snapshot.deleteItems([.loadMore])
        }
    }

    func loadMoreIfNeeded(_ scrollView: UIScrollView) {
        guard hasLoadMore else {
            return
        }

        var threshold = scrollView.contentSize.height
        threshold -= scrollView.bounds.height * 2

        guard scrollView.contentOffset.y > threshold else {
            return
        }

        presenter.loadMore()
    }

    func reloadCollectionView() {
        var snapshot = dataSource.snapshot()
        snapshot.reloadSections(snapshot.sectionIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    @objc func actionSearch() {
        presenter.activateSearch()
    }
}

extension PayShopViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch dataSource.itemIdentifier(for: indexPath) {
        case let .brand(viewModel):
            presenter.select(brand: viewModel)
        default:
            break
        }
    }

    func collectionView(
        _: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt _: IndexPath
    ) {
        if let loadMoreCell = cell as? PayShopLoadMoreCell {
            loadMoreCell.view.startLoading()
        }

        if let skeletonCell = cell as? PayShopSkeletonBrandCell {
            skeletonCell.startLoading()
        }
    }

    func collectionView(
        _: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt _: IndexPath
    ) {
        if let loadMoreCell = cell as? PayShopLoadMoreCell {
            loadMoreCell.view.stopLoading()
        }

        if let skeletonCell = cell as? PayShopSkeletonBrandCell {
            skeletonCell.stopLoading()
        }
    }
}

extension PayShopViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewTracker?.trackScrollViewDidChangeOffset(scrollView.contentOffset)

        loadMoreIfNeeded(scrollView)
    }
}

extension PayShopViewController: ScrollViewHostProtocol {
    var initialTrackingInsets: UIEdgeInsets {
        rootView.collectionView.adjustedContentInset
    }
}

extension PayShopViewController: ScrollsToTop {
    func scrollToTop() {
        rootView.collectionView.setContentOffset(
            CGPoint(x: 0, y: -initialTrackingInsets.top),
            animated: true
        )
    }
}

extension PayShopViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            reloadCollectionView()
        }
    }
}

extension PayShopViewController: PayShopViewProtocol {
    func didReceive(availabilityViewModel: PayShopAvailabilityViewModel) {
        var snapshot = dataSource.snapshot()

        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .availability))
        snapshot.appendItems([.availability(availabilityViewModel)], toSection: .availability)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func didReload(viewModels: [PayShopBrandViewModel], hasMore: Bool) {
        var snapshot = dataSource.snapshot()

        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .brands))

        let items = viewModels.map { Item.brand($0) }

        snapshot.appendItems(items, toSection: .brands)

        updateLoadMoreCell(in: &snapshot, hasMore: hasMore)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func didLoad(viewModels: [PayShopBrandViewModel], hasMore: Bool) {
        var snapshot = dataSource.snapshot()

        let items = viewModels.map { Item.brand($0) }

        snapshot.appendItems(items, toSection: .brands)

        updateLoadMoreCell(in: &snapshot, hasMore: hasMore)

        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

private extension PayShopViewController {
    enum Constants {
        static let brandCellHeight: CGFloat = 64
        static let brandCellSpacing: CGFloat = 8
    }
}
