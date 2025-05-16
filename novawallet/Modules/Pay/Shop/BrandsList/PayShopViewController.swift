import UIKit

final class PayShopViewController: UIViewController, ViewHolder {
    typealias RootViewType = PayShopViewLayout

    typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    enum Section: Int, CaseIterable {
        case availability
        case purchases
        case recommended
        case brands
    }

    enum Item: Identifiable, Hashable {
        case availability(PayShopAvailabilityViewModel)
        case purchases(Int)
        case recommended(PayShopRecommendedViewModel)
        case brand(PayShopBrandViewModel)

        var id: String {
            switch self {
            case .availability:
                "shop.availability"
            case .purchases:
                "shop.purchases"
            case let .recommended(viewModel):
                "shop.recommended.\(viewModel.identifier)"
            case let .brand(viewModel):
                "shop.brand.\(viewModel.identifier)"
            }
        }
    }

    let presenter: PayShopPresenterProtocol

    private lazy var dataSource = createDataSource()

    weak var scrollViewTracker: ScrollViewTrackingProtocol?

    init(presenter: PayShopPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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
            cell.bind(viewModel: viewModel, locale: Locale.current)
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

            return view
        default:
            return UICollectionReusableView()
        }
    }

    func setupInitialDataSource() {
        var snapshot = Snapshot()

        snapshot.appendSections([.availability, .brands])
        snapshot.appendItems([.availability(.available(.loading))], toSection: .availability)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension PayShopViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt _: IndexPath) {}
}

extension PayShopViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewTracker?.trackScrollViewDidChangeOffset(scrollView.contentOffset)
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

extension PayShopViewController: PayShopViewProtocol {
    func didReceive(availabilityViewModel: PayShopAvailabilityViewModel) {
        var snapshot = dataSource.snapshot()

        snapshot.deleteSections([.availability])
        snapshot.insertSections([.availability], beforeSection: .brands)
        snapshot.appendItems([.availability(availabilityViewModel)], toSection: .availability)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func didReload(viewModels: [PayShopBrandViewModel]) {
        var snapshot = dataSource.snapshot()

        snapshot.deleteSections([.brands])
        snapshot.appendSections([.brands])

        let items = viewModels.map { Item.brand($0) }

        snapshot.appendItems(items, toSection: .brands)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func didLoad(viewModels: [PayShopBrandViewModel]) {
        var snapshot = dataSource.snapshot()

        let items = viewModels.map { Item.brand($0) }

        snapshot.appendItems(items, toSection: .brands)

        dataSource.apply(snapshot, animatingDifferences: true)
    }
}
