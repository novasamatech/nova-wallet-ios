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
        backgroundColor = R.color.colorSecondaryScreenBackground()

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
        let settings = NSCollectionLayoutSection.Settings(
            estimatedRowHeight: Constants.estimatedRowHeight,
            absoluteHeaderHeight: Constants.absoluteHeaderHeight,
            estimatedHeaderHeight: Constants.absoluteHeaderHeight,
            sectionContentInsets: Constants.sectionContentInsets,
            sectionInterGroupSpacing: Constants.interGroupSpacing,
            header: .init(pinToVisibleBounds: false)
        )

        return UICollectionViewCompositionalLayout(section:
            .createSectionLayoutWithFullWidthRow(settings: settings)
        )
    }
}

// MARK: - Constants

extension CurrencyViewLayout {
    private enum Constants {
        static let estimatedRowHeight: CGFloat = 56
        static let absoluteHeaderHeight: CGFloat = 18
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
