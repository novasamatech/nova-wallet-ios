import Foundation
import Operation_iOS

enum ManageTokensTab: Int {
    case tokens = 0
    case networks = 1
}

protocol TokensManageViewProtocol: ControllerBackedProtocol {
    func didReceive(sections: [ManageTokenSection])
    func didReceive(hidesZeroBalances: Bool)
    func didReceive(dustFilterEnabled: Bool)
    func didReceive(dustFilterThreshold: Decimal)
    func didReceive(selectAllTitle: String)
}

protocol TokensManagePresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func performAddToken()
    func performTabSwitch(to tab: ManageTokensTab)
    func performToggleSection(at index: Int)
    func performSwitch(for item: ManageTokenItem, enabled: Bool)
    func performSelectAll()
    func performFilterChange(to value: Bool)
    func performDustFilterChange(to value: Bool)
    func performDustThresholdChange(to value: Decimal)
}

protocol TokensManageInteractorInputProtocol: AnyObject {
    func setup()
    func save(chainAssetIds: Set<ChainAssetId>, enabled: Bool, allChains: [ChainModel])
    func save(hideZeroBalances: Bool)
    func save(dustFilterEnabled: Bool)
    func save(dustFilterThreshold: Decimal)
    func getDefaultTokenIds() -> Set<ChainAssetId>?
    func getUserAddedTokens() -> Set<ChainAssetId>
    func addUserAddedToken(_ chainAssetId: ChainAssetId)
    func removeUserAddedToken(_ chainAssetId: ChainAssetId)
    func isDefaultFilterActive() -> Bool
    func fetchDefaultFilterState(completion: @escaping (Bool, Set<ChainAssetId>, Set<ChainAssetId>) -> Void)
}

protocol TokensManageInteractorOutputProtocol: AnyObject {
    func didReceiveChainModel(changes: [DataProviderChange<ChainModel>])
    func didReceive(hideZeroBalances: Bool)
    func didReceive(dustFilterEnabled: Bool, threshold: Decimal)
    func didFailChainSave()
}

extension TokensManageInteractorOutputProtocol {
    func didReceive(hideZeroBalances _: Bool) {}
    func didReceive(dustFilterEnabled _: Bool, threshold _: Decimal) {}
}

protocol TokensManageWireframeProtocol: AlertPresentable {
    func showAddToken(from view: TokensManageViewProtocol?)
}
