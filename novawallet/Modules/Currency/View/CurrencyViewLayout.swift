import UIKit
import SnapKit

final class CurrencyViewLayout: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        backgroundColor = R.color.colorBlack()

        addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createCompositionalLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = Constants.collectionViewContentInset
        return view
    }()

    private func createCompositionalLayout() -> UICollectionViewCompositionalLayout {
        .createWholeWidthRowCompositionalLayout(settings:
            .init(
                estimatedRowHeight: Constants.estimatedRowHeight,
                estimatedHeaderHeight: Constants.estimatedHeaderHeight,
                sectionContentInsets: Constants.sectionContentInsets,
                sectionInterGroupSpacing: Constants.interGroupSpacing,
                headerPinToVisibleBounds: false
            ))
    }
}

// MARK: - Constants

extension CurrencyViewLayout {
    private enum Constants {
        static let estimatedRowHeight: CGFloat = 56
        static let estimatedHeaderHeight: CGFloat = 44
        static let sectionContentInsets = NSDirectionalEdgeInsets(
            top: 4,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
        static let interGroupSpacing: CGFloat = 0
        static let collectionViewContentInset = UIEdgeInsets(
            top: 8,
            left: 0,
            bottom: 16,
            right: 0
        )
    }
}

extension UICollectionViewCompositionalLayout {
    struct Settings {
        let estimatedRowHeight: CGFloat
        let estimatedHeaderHeight: CGFloat
        let sectionContentInsets: NSDirectionalEdgeInsets
        let sectionInterGroupSpacing: CGFloat
        let headerPinToVisibleBounds: Bool
    }

    static func createWholeWidthRowCompositionalLayout(settings: Settings) -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(settings.estimatedRowHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(settings.estimatedHeaderHeight)
        )
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )
        sectionHeader.pinToVisibleBounds = settings.headerPinToVisibleBounds
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = settings.sectionContentInsets
        section.interGroupSpacing = settings.sectionInterGroupSpacing
        section.boundarySupplementaryItems = [sectionHeader]

        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
}
