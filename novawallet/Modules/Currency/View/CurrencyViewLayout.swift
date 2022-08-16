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
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(Constants.estimatedRowHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(Constants.estimatedHeaderHeight)
        )
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = Constants.sectionContentInsets
        section.interGroupSpacing = Constants.interGroupSpacing
        section.boundarySupplementaryItems = [sectionHeader]

        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
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
            bottom: 16.0,
            right: 0
        )
    }
}
