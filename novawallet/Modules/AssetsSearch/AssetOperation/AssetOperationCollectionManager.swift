import Foundation

class AssetOperationCollectionManager: AssetsSearchCollectionManager {
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