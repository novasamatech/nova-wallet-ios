import UIKit

final class SendAssetOperationViewController: AssetsSearchViewController {
    var sendPresenter: SendAssetOperationPresenterProtocol? {
        presenter as? SendAssetOperationPresenterProtocol
    }

    override func provideEmptyStateCell(
        _ collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard rootView.searchBar.textField.text.isNilOrEmpty else {
            return super.provideEmptyStateCell(collectionView, indexPath: indexPath)
        }

        let cell = collectionView.dequeueReusableCellWithType(
            AssetListEmptyCell.self,
            for: indexPath
        )!

        let text = R.string.localizable.assetOperationSendEmptyStateMessage(
            preferredLanguages: selectedLocale.rLanguages)
        let actionTitle = R.string.localizable.walletListEmptyActionTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        cell.bind(text: text, actionTitle: actionTitle)
        cell.actionButton.addTarget(self, action: #selector(actionBuy), for: .touchUpInside)
        cell.actionButton.isHidden = false

        return cell
    }

    override func emptyStateCellHeight(indexPath: IndexPath) -> CGFloat {
        let searchTextEmpty = rootView.searchBar.textField.text.isNilOrEmpty

        switch (searchTextEmpty, AssetsSearchFlowLayout.CellType(indexPath: indexPath)) {
        case (true, .emptyState):
            return AssetsSearchMeasurement.emptySearchCellWithActionHeight
        default:
            return super.emptyStateCellHeight(indexPath: indexPath)
        }
    }

    @objc
    private func actionBuy() {
        sendPresenter?.buy()
    }
}
