import UIKit

final class PayShopViewLayout: UIView {
    private var dataSource: DataSource!

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension PayShopViewLayout {
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
}

private extension PayShopViewLayout {
    func createCompositionalLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { [unowned self] sectionIndex, _ in
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
            }
        }

        return layout
    }

    func createAvailabilitySection() -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(
            settings: .init(
                estimatedRowHeight: Constants.availabilityHeight,
                sectionContentInsets: Constants.headerSectionInsets,
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
                sectionInterGroupSpacing: Constants.brandCellHeight,
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
}

private enum Constants {
    static let headerHeight: CGFloat = 40
    static let headerSectionInsets = NSDirectionalEdgeInsets(
        top: 12,
        leading: 16,
        bottom: 0,
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
        bottom: 0,
        trailing: 16
    )

    static let recommendedItemWidth: CGFloat = 162
    static let recommendedItemHeight: CGFloat = 110
    static let recommendedItemSpacing: CGFloat = 12

    static let brandsSectionInsets = NSDirectionalEdgeInsets(
        top: 16,
        leading: 16,
        bottom: 0,
        trailing: 16
    )

    static let searchHeaderHeight: CGFloat = 32

    static let brandCellHeight: CGFloat = 64

    static let brandCellSpacing: CGFloat = 8
}
