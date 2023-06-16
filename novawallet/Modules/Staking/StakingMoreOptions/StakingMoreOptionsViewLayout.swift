import UIKit

final class StakingMoreOptionsViewLayout: UIView {
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: compositionalLayout)
        compositionalLayout.register(
            BlurBackgroundCollectionReusableView.self,
            forDecorationViewOfKind: BlurBackgroundCollectionReusableView.reuseIdentifier
        )
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = .init(top: 16, left: 16, bottom: 16, right: 16)
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

    private func setupLayout() {
        addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    private lazy var compositionalLayout: UICollectionViewCompositionalLayout = {
        .init { sectionIndex, _ -> NSCollectionLayoutSection? in
            switch StakingMoreOptionsSection(rawValue: sectionIndex) {
            case .options:
                return Self.createOptionsSection()
            case .dApps:
                return Self.createDAppsSection()
            default:
                return nil
            }
        }
    }()

    static func createOptionsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(64)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .zero
        section.interGroupSpacing = 8

        return section
    }

    static func createDAppsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(64)
        )

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(32)
        )

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .zero
        section.interGroupSpacing = 0

        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading,
            absoluteOffset: .init(x: 0, y: -20)
        )
        sectionHeader.pinToVisibleBounds = false

        section.boundarySupplementaryItems = [sectionHeader]
        section.decorationItems = [
            NSCollectionLayoutDecorationItem.background(elementKind: BlurBackgroundCollectionReusableView.reuseIdentifier)
        ]
        return section
    }
}

enum StakingMoreOptionsSection: Int, CaseIterable {
    case options
    case dApps
}
