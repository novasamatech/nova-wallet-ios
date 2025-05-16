import UIKit

final class PayShopViewLayout: UIView {
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createCompositionalLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension PayShopViewLayout {
    func setupLayout() {
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func createCompositionalLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { [unowned self] sectionIndex, _ in
            guard
                let dataSource = collectionView.dataSource as? PayShopViewController.DataSource else {
                fatalError("DataSource not set")
            }

            let snap = dataSource.snapshot()
            let section = snap.sectionIdentifiers[sectionIndex]

            switch section {
            case .availability:
                return createAvailabilitySection()
            case .purchases:
                return createPurchasesSection()
            case .recommended:
                return createRecommendedSection()
            case .brands:
                return createBrandsSection()
            case .loadMore:
                return createLoadMoreSection()
            }
        }

        return layout
    }

    func createAvailabilitySection() -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(
            settings: .init(
                estimatedRowHeight: Constants.availabilityHeight,
                sectionContentInsets: Constants.availabilitySectionInsets,
                sectionInterGroupSpacing: 0,
                header: nil
            )
        )
    }

    func createRecommendedSection() -> NSCollectionLayoutSection {
        .createOrthogonalHorizontalSection(
            settings: .init(
                estimatedRowWidth: Constants.recommendedItemWidth,
                rowHeight: Constants.recommendedItemHeight,
                sectionContentInsets: Constants.recommendedSectionInsets,
                sectionInterGroupSpacing: Constants.recommendedItemSpacing,
                header: nil
            )
        )
    }

    func createBrandsSection() -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(
            settings: .init(
                estimatedRowHeight: Constants.brandCellHeight,
                sectionContentInsets: Constants.brandsSectionInsets,
                sectionInterGroupSpacing: Constants.brandCellSpacing,
                header: .init(
                    pinToVisibleBounds: false,
                    height: .absolute(Constants.searchHeaderHeight)
                )
            )
        )
    }

    func createPurchasesSection() -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(
            settings: .init(
                estimatedRowHeight: Constants.purchasesHeight,
                sectionContentInsets: Constants.purchasesSectionInsets,
                sectionInterGroupSpacing: 0,
                header: nil
            )
        )
    }

    func createLoadMoreSection() -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(
            settings: .init(
                estimatedRowHeight: Constants.loadMoreEstimatedHeight,
                sectionContentInsets: Constants.loadMoreSectionInsets,
                sectionInterGroupSpacing: 0,
                header: nil
            )
        )
    }
}

private enum Constants {
    static let availabilitySectionInsets = NSDirectionalEdgeInsets(
        top: 32,
        leading: 16,
        bottom: 18,
        trailing: 16
    )

    static let availabilityHeight: CGFloat = 88

    static let purchasesHeight: CGFloat = 52

    static let purchasesSectionInsets = NSDirectionalEdgeInsets(
        top: 16,
        leading: 16,
        bottom: 0,
        trailing: 16
    )

    static let recommendedSectionInsets = NSDirectionalEdgeInsets(
        top: 16,
        leading: 16,
        bottom: 18,
        trailing: 16
    )

    static let recommendedItemWidth: CGFloat = 162
    static let recommendedItemHeight: CGFloat = 110
    static let recommendedItemSpacing: CGFloat = 12

    static let brandsSectionInsets = NSDirectionalEdgeInsets(
        top: 12,
        leading: 16,
        bottom: 0,
        trailing: 16
    )

    static let searchHeaderHeight: CGFloat = 32

    static let brandCellHeight: CGFloat = 64

    static let brandCellSpacing: CGFloat = 8

    static let loadMoreSectionInsets = NSDirectionalEdgeInsets(
        top: 16,
        leading: 16,
        bottom: 16,
        trailing: 16
    )

    static let loadMoreEstimatedHeight: CGFloat = 50
}
