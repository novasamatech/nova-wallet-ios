import UIKit

class SendAssetOperationCollectionManager: AssetsSearchCollectionManager {
    var dataSource: SendAssetOperationCollectionDataSource? {
        get {
            collectionViewDataSource as? SendAssetOperationCollectionDataSource
        }
        set {
            collectionViewDataSource = newValue ?? collectionViewDataSource
        }
    }

    weak var actionDelegate: SendAssetOperationCollectionManagerActionDelegate?

    override func setup() {
        dataSource?.groupsLayoutDelegate = self
        dataSource?.delegate = self

        collectionViewDelegate.selectionDelegate = self
        collectionViewDelegate.groupsLayoutDelegate = self

        view?.collectionView.dataSource = collectionViewDataSource
        view?.collectionView.delegate = collectionViewDelegate
    }

    init(
        view: BaseAssetsSearchViewLayout,
        groupsViewModel: AssetListViewModel,
        delegate: AssetsSearchCollectionManagerDelegate? = nil,
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
