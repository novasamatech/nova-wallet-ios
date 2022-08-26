import UIKit

final class YourWalletsViewLayout: UIView {
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: compositionalLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = Constants.collectionViewContentInset
        view.bounces = false
        return view
    }()

    private lazy var compositionalLayout: UICollectionViewCompositionalLayout = {
        .init { sectionIndex, _ -> NSCollectionLayoutSection? in
            switch sectionIndex {
            case 0:
                return Self.createCompositionalLayout(showHeader: false)
            default:
                return Self.createCompositionalLayout(showHeader: true)
            }
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.color0x1D1D20()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private static func createCompositionalLayout(showHeader: Bool) -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(settings:
            .init(
                estimatedRowHeight: Constants.estimatedRowHeight,
                estimatedHeaderHeight: Constants.estimatedHeaderHeight,
                sectionContentInsets: Constants.sectionContentInsets,
                sectionInterGroupSpacing: Constants.interGroupSpacing,
                header: showHeader ? .init(pinToVisibleBounds: true) : nil
            ))
    }
}

// MARK: - Constants

extension YourWalletsViewLayout {
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
