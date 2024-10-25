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

        setup()
    }

    override func setup() {
//        let layout = SendAssetOperationTokensFlowLayout()
//        view?.collectionTokenGroupsLayout = layout
//        view?.collectionView.setCollectionViewLayout(layout, animated: false)

        dataSource?.groupsLayoutDelegate = self
        dataSource?.delegate = self

        collectionViewDelegate.selectionDelegate = self
        collectionViewDelegate.groupsLayoutDelegate = self

        view?.collectionView.dataSource = collectionViewDataSource
        view?.collectionView.delegate = collectionViewDelegate
    }

    override func updateTokensGroupLayout() {
        guard
            let tokenGroupsLayout,
            groupsViewModel.listGroupStyle == .tokens
        else {
            return
        }

        groupsViewModel.listState.groups.enumerated().forEach { _, group in
            guard case let .token(groupViewModel) = group else {
                return
            }

            tokenGroupsLayout.setExpandableSection(
                for: groupViewModel.token.symbol,
                false
            )
        }
    }

    override func groupExpandable(for _: String) -> Bool {
        false
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
