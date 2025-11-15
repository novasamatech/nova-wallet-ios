import UIKit
import SnapKit

final class StakingMoreOptionsViewLayout: UIView {
    let backgroundView = UIImageView.background

    let navBarBlurView: BlurBackgroundView = .create {
        $0.cornerCut = []
    }

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(
            frame: .zero,
            collectionViewLayout: compositionalLayout
        )
        compositionalLayout.register(
            BlurBackgroundCollectionReusableView.self,
            forDecorationViewOfKind: BlurBackgroundCollectionReusableView.reuseIdentifier
        )
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

    private func setupLayout() {
        addSubview(backgroundView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(navBarBlurView)
        navBarBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
        }
    }

    private lazy var compositionalLayout: UICollectionViewCompositionalLayout = {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return .init(sectionProvider: { sectionIndex, _ -> NSCollectionLayoutSection? in
            switch StakingMoreOptionsSection(rawValue: sectionIndex) {
            case .options:
                return Self.createOptionsSection()
            case .dApps:
                return Self.createDAppsSection()
            default:
                return nil
            }
        }, configuration: configuration)
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
        section.contentInsets = .init(top: 16, leading: 0, bottom: 28, trailing: 0)
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
        section.contentInsets = .init(top: 13, leading: 16, bottom: 16, trailing: 16)
        section.interGroupSpacing = 0

        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading,
            absoluteOffset: .init(x: 0, y: -20)
        )
        sectionHeader.pinToVisibleBounds = false

        section.boundarySupplementaryItems = [sectionHeader]
        let decorationItem = NSCollectionLayoutDecorationItem.background(
            elementKind: BlurBackgroundCollectionReusableView.reuseIdentifier
        )
        decorationItem.contentInsets = .init(top: 28, leading: 16, bottom: 13, trailing: 16)

        section.decorationItems = [
            decorationItem
        ]
        return section
    }
}
