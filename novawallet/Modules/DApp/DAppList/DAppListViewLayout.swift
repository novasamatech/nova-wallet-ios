import UIKit

final class DAppListViewLayout: UIView {
    private let backgroundView = MultigradientView.background

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(
            frame: .zero,
            collectionViewLayout: createLayout()
        )
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 16.0, right: 0.0)
        view.refreshControl = UIRefreshControl()

        return view
    }()

    var sectionViewModels: [DAppListSectionViewModel] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func findHeaderView() -> DAppListHeaderView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? DAppListHeaderView
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }
    }
}

// MARK: Private

private extension DAppListViewLayout {
    func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] (index, _) -> NSCollectionLayoutSection? in
            guard
                let self,
                index < sectionViewModels.count
            else { return nil }

            var section: NSCollectionLayoutSection?
            var contentInsets: NSDirectionalEdgeInsets = .zero

            switch sectionViewModels[index] {
            case .header:
                section = maxWidthsection(
                    fixedHeight: 108,
                    scrollingBehavior: .none
                )
            case .categorySelect:
                section = maxWidthsection(
                    fixedHeight: DAppCategoriesView.preferredHeight,
                    scrollingBehavior: .none
                )
                contentInsets.bottom = 8
            case .favorites:
                section = dAppFavoritesSectionLayout()
                contentInsets.bottom = 24
                contentInsets.top = 12
            case .category:
                section = dAppCategorySectionLayout()
                contentInsets.bottom = 24
                contentInsets.top = 12
                contentInsets.trailing = bounds.width * 0.25
            }
            section?.contentInsets = contentInsets

            return section
        }
    }

    func dAppFavoritesSectionLayout() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .absolute(80),
                heightDimension: .absolute(88)
            )
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(88)
            ),
            subitem: item,
            count: 1
        )

        let header = headerLayoutItem()

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.boundarySupplementaryItems = [header]

        return section
    }

    func dAppCategorySectionLayout() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(64)
            )
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            ),
            subitem: item,
            count: 3
        )
        let containerGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.85),
                heightDimension: .absolute(item.layoutSize.heightDimension.dimension * 3)
            ),
            subitem: group,
            count: 1
        )

        let header = headerLayoutItem()

        let section = NSCollectionLayoutSection(group: containerGroup)
        section.orthogonalScrollingBehavior = .groupPaging
        section.boundarySupplementaryItems = [header]
        section.interGroupSpacing = 16

        return section
    }

    func maxWidthsection(
        fixedHeight: CGFloat,
        scrollingBehavior: UICollectionLayoutSectionOrthogonalScrollingBehavior
    ) -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(fixedHeight)
            ),
            subitem: item,
            count: 1
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = scrollingBehavior

        return section
    }

    func headerLayoutItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(24.0)
            ),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}
