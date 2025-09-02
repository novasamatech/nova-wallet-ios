import Foundation
import UIKit

// MARK: UICollectionViewDataSource

extension BannersViewController: UICollectionViewDataSource {
    func collectionView(
        _: UICollectionView,
        numberOfItemsInSection _: Int
    ) -> Int {
        dataSource.numberOfItems()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let viewModel = dataSource.getItem(at: indexPath.item) else {
            return UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCellWithType(
            BannerCollectionViewCell.self,
            for: indexPath
        )!

        cell.bind(with: viewModel)

        return cell
    }
}

// MARK: UICollectionViewDelegate

extension BannersViewController: UICollectionViewDelegate {
    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard let viewModel = dataSource.getItem(at: indexPath.item) else {
            return
        }

        presenter.action(for: viewModel.id)
    }
}

// MARK: UICollectionViewDelegateFlowLayout

extension BannersViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt _: IndexPath
    ) -> CGSize {
        let height = max(maxContentHeight, BannersViewLayout.Constants.contentMinHeight)

        return CGSize(
            width: rootView.backgroundView.bounds.width,
            height: height
        )
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt _: Int
    ) -> CGFloat {
        .zero
    }
}
