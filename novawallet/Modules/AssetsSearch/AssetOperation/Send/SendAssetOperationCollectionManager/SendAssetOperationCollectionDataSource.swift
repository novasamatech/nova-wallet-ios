import UIKit

protocol SendAssetOperationCollectionDataSourceDelegate: AnyObject {
    func textFieldIsEmpty() -> Bool
    func actionBuy()
}

class SendAssetOperationCollectionDataSource: AssetsSearchCollectionViewDataSource {
    weak var delegate: SendAssetOperationCollectionDataSourceDelegate?

    override func provideEmptyStateCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard delegate?.textFieldIsEmpty() == true else {
            return super.provideEmptyStateCell(collectionView, indexPath: indexPath)
        }

        let cell = collectionView.dequeueReusableCellWithType(
            AssetListEmptyCell.self,
            for: indexPath
        )!

        let text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.assetOperationSendEmptyStateMessage()
        let actionTitle = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.walletListEmptyActionTitle()

        cell.bind(text: text, actionTitle: actionTitle)
        cell.actionButton.addTarget(self, action: #selector(actionBuy), for: .touchUpInside)
        cell.actionButton.isHidden = false

        return cell
    }

    override func emptyStateCellHeight(indexPath: IndexPath) -> CGFloat {
        let searchTextEmpty = delegate?.textFieldIsEmpty() == true

        switch (searchTextEmpty, AssetsSearchFlowLayout.CellType(indexPath: indexPath)) {
        case (true, .emptyState):
            return AssetsSearchMeasurement.emptySearchCellWithActionHeight
        default:
            return super.emptyStateCellHeight(indexPath: indexPath)
        }
    }

    @objc
    private func actionBuy() {
        delegate?.actionBuy()
    }
}
