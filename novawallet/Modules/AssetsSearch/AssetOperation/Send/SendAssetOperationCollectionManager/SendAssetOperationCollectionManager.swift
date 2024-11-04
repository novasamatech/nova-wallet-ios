import UIKit

typealias SendAssetOperationCollectionDelegate = AssetsSearchCollectionManagerDelegate
    & SendAssetOperationCollectionManagerActionDelegate

class SendAssetOperationCollectionManager: AssetOperationCollectionManager {
    var dataSource: SendAssetOperationCollectionDataSource? {
        get {
            collectionViewDataSource as? SendAssetOperationCollectionDataSource
        }
        set {
            collectionViewDataSource = newValue ?? collectionViewDataSource
        }
    }

    weak var actionDelegate: SendAssetOperationCollectionManagerActionDelegate?

    init(
        view: BaseAssetsSearchViewLayout,
        groupsViewModel: AssetListViewModel,
        delegate: SendAssetOperationCollectionDelegate? = nil,
        actionDelegate: SendAssetOperationCollectionManagerActionDelegate? = nil,
        selectedLocale: Locale
    ) {
        super.init(
            view: view,
            groupsViewModel: groupsViewModel,
            delegate: delegate,
            selectedLocale: selectedLocale
        )

        collectionViewDataSource = SendAssetOperationCollectionDataSource(
            groupsViewModel: groupsViewModel,
            selectedLocale: selectedLocale
        )

        self.actionDelegate = actionDelegate

        setup()
    }

    override func setup() {
        dataSource?.groupsLayoutDelegate = self
        dataSource?.delegate = self

        collectionViewDelegate.selectionDelegate = self
        collectionViewDelegate.groupsLayoutDelegate = self

        view?.collectionView.dataSource = dataSource
        view?.collectionView.delegate = collectionViewDelegate
    }
}

extension SendAssetOperationCollectionManager: SendAssetOperationCollectionDataSourceDelegate {
    func textFieldIsEmpty() -> Bool {
        view?.searchBar.textField.text.isNilOrEmpty ?? true
    }

    func actionBuy() {
        actionDelegate?.actionBuy()
    }
}
