import UIKit

final class YourWalletsViewLayout: UIView {
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createCompositionalLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = Constants.collectionViewContentInset
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
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

    private func createCompositionalLayout() -> UICollectionViewCompositionalLayout {
        .createWholeWidthRowCompositionalLayout(settings:
            .init(
                estimatedRowHeight: Constants.estimatedRowHeight,
                estimatedHeaderHeight: Constants.estimatedHeaderHeight,
                sectionContentInsets: Constants.sectionContentInsets,
                sectionInterGroupSpacing: Constants.interGroupSpacing,
                headerPinToVisibleBounds: true
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
