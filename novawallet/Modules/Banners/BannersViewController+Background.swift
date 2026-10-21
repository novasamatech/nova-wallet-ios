import UIKit

extension BannersViewController {
    func updateBackground() {
        let lastItemIndex = dataSource.numberOfItems() - 1

        guard lastItemIndex >= 0 else { return }

        let position = currentItemPosition(lastItemIndex: lastItemIndex)

        if let pinnedItemIndex = pinnedBackgroundItemIndex, position != CGFloat(pinnedItemIndex) {
            setBackground(itemIndex: pinnedItemIndex, nextItemIndex: pinnedItemIndex, progress: 0)
            return
        }

        pinnedBackgroundItemIndex = nil

        guard let position else { return }

        let itemIndex = Int(position.rounded(.down))

        setBackground(
            itemIndex: itemIndex,
            nextItemIndex: min(itemIndex + 1, lastItemIndex),
            progress: position - CGFloat(itemIndex)
        )
    }

    func unpinBackground() {
        guard pinnedBackgroundItemIndex != nil else { return }

        pinnedBackgroundItemIndex = nil
        updateBackground()
    }
}

// MARK: Private

private extension BannersViewController {
    func currentItemPosition(lastItemIndex: Int) -> CGFloat? {
        let collectionView = rootView.collectionView
        let itemWidth = collectionView.bounds.width

        guard itemWidth > 0 else { return nil }

        let position = min(max(collectionView.contentOffset.x / itemWidth, 0), CGFloat(lastItemIndex))
        let nearestItemPosition = position.rounded()

        return abs(position - nearestItemPosition) < Constants.itemPositionTolerance
            ? nearestItemPosition
            : position
    }

    func setBackground(
        itemIndex: Int,
        nextItemIndex: Int,
        progress: CGFloat
    ) {
        rootView.backgroundView.setBackground(
            dataSource.getItem(at: itemIndex)?.backgroundImage,
            blendingTo: dataSource.getItem(at: nextItemIndex)?.backgroundImage,
            progress: progress
        )
    }

    enum Constants {
        static let itemPositionTolerance: CGFloat = 0.000_001
    }
}
