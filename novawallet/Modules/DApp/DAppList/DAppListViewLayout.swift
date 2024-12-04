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

    private var sectionViewModels: [DAppListSection] = []

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
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = 16.0

        let sectionProvider: UICollectionViewCompositionalLayoutSectionProvider
        sectionProvider = { [weak self] (index, _) -> NSCollectionLayoutSection? in
            switch Section(for: index) {
            case .favorites: self?.dAppFavoritesSectionLayout()
            case .category: self?.dAppCategorySectionLayout()
            default: nil
            }
        }

        return UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider,
            configuration: configuration
        )
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
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: 0,
            trailing: 16
        )

        return section
    }

    func dAppCategorySectionLayout() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.75),
                heightDimension: .absolute(88)
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
        let containerGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.75),
                heightDimension: .fractionalHeight(0.80)
            ),
            subitem: group,
            count: 1
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(24.0)
            ),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        let section = NSCollectionLayoutSection(group: containerGroup)
        section.orthogonalScrollingBehavior = .continuous
        section.boundarySupplementaryItems = [header]
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: 0,
            trailing: 16
        )

        return section
    }
}

extension DAppListViewLayout {
    enum Section {
        case header
        case categorySelect
        case favorites
        case category

        init(for index: Int) {
            switch index {
            case 0: self = .header
            case 1: self = .categorySelect
            case 2: self = .favorites
            default: self = .category
            }
        }
    }
}
