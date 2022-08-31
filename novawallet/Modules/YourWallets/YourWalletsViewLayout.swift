import UIKit

final class YourWalletsViewLayout: UIView {
    lazy var header: IconTitleHeaderView = .create {
        $0.contentInsets = Constants.headerContentInsets
    }

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: compositionalLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = Constants.collectionViewContentInset
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
        addSubview(header)
        addSubview(collectionView)

        header.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.height.equalTo(Constants.headerHeight)
            $0.leading.trailing.equalToSuperview()
        }

        collectionView.snp.makeConstraints {
            $0.top.equalTo(header.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private static func createCompositionalLayout(showHeader: Bool) -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(settings:
            .init(
                estimatedRowHeight: Constants.estimatedRowHeight,
                estimatedHeaderHeight: Constants.estimatedSectionHeaderHeight,
                sectionContentInsets: Constants.sectionContentInsets,
                sectionInterGroupSpacing: Constants.interGroupSpacing,
                header: showHeader ? .init(pinToVisibleBounds: true) : nil
            ))
    }
}

// MARK: - Constants

extension YourWalletsViewLayout {
    private enum Constants {
        static let headerHeight: CGFloat = 46
        static let estimatedRowHeight: CGFloat = 56
        static let estimatedSectionHeaderHeight: CGFloat = 46
        static let sectionContentInsets = NSDirectionalEdgeInsets(
            top: 4,
            leading: 16,
            bottom: 16,
            trailing: 16
        )
        static let interGroupSpacing: CGFloat = 0
        static let collectionViewContentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: 16,
            right: 0
        )
        static let headerContentInsets = UIEdgeInsets(
            top: 12,
            left: 0,
            bottom: 12,
            right: 0
        )
    }
}

extension YourWalletsViewLayout {
    static func contentHeight(sections: Int, items: Int) -> CGFloat {
        let itemHeight =
            Constants.estimatedRowHeight +
            Constants.estimatedSectionHeaderHeight

        let sectionsHeight = Constants.estimatedSectionHeaderHeight +
            Constants.sectionContentInsets.top +
            Constants.sectionContentInsets.bottom

        let estimatedHeight = Constants.collectionViewContentInset.top +
            CGFloat(items) * itemHeight +
            CGFloat(max(sections - 1, 0)) * sectionsHeight +
            Constants.collectionViewContentInset.bottom

        return estimatedHeight
    }
}
