import Foundation

typealias AssetOperationCollectionDelegate = AssetsSearchCollectionManagerDelegate
    & AssetOperationCollectionManagerDelegate

class AssetOperationCollectionManager: AssetsSearchCollectionManager {
    weak var delegate: AssetOperationCollectionManagerDelegate?

    init(
        view: BaseAssetsSearchViewLayout,
        groupsViewModel: AssetListViewModel,
        delegate: AssetOperationCollectionDelegate?,
        selectedLocale: Locale
    ) {
        super.init(
            view: view,
            groupsViewModel: groupsViewModel,
            delegate: delegate,
            selectedLocale: selectedLocale
        )

        self.delegate = delegate
    }

    override func selectGroup(
        with symbol: AssetModel.Symbol,
        at indexPath: IndexPath
    ) {
        super.selectGroup(with: symbol, at: indexPath)

        delegate?.selectGroup(with: symbol)
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
