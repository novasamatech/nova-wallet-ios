import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol AssetListViewProtocol: ControllerBackedProtocol {
    func didReceiveHeader(viewModel: AssetListHeaderViewModel)
    func didReceiveGroups(state: AssetListGroupState)
    func didReceiveNft(viewModel: AssetListNftsViewModel?)
    func didCompleteRefreshing()
}

protocol AssetListPresenterProtocol: AnyObject {
    func setup()
    func selectWallet()
    func selectAsset(for chainAssetId: ChainAssetId)
    func selectNfts()
    func refresh()
    func presentSettings()
    func presentSearch()
    func presentAssetsManage()
    func presentLocks()
    func send()
    func receive()
}

protocol AssetListInteractorInputProtocol: AssetListBaseInteractorInputProtocol {
    func refresh()
}

protocol AssetListInteractorOutputProtocol: AssetListBaseInteractorOutputProtocol {
    func didReceive(walletIdenticon: Data?, walletType: MetaAccountModelType, name: String)
    func didReceiveNft(changes: [DataProviderChange<NftModel>])
    func didReceiveNft(error: Error)
    func didResetNftProvider()
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)
    func didChange(name: String)
    func didReceive(hidesZeroBalances: Bool)
    func didReceiveLocks(result: Result<[AssetLock], Error>)
}

protocol AssetListWireframeProtocol: AnyObject, WalletSwitchPresentable {
    func showAssetDetails(from view: AssetListViewProtocol?, chain: ChainModel, asset: AssetModel)
    func showAssetsSettings(from view: AssetListViewProtocol?)
    func showTokensManage(from view: AssetListViewProtocol?)

    func showAssetsSearch(
        from view: AssetListViewProtocol?,
        initState: AssetListInitState,
        delegate: AssetsSearchDelegate
    )

    func showNfts(from view: AssetListViewProtocol?)

    func showBalanceBreakdown(
        from view: AssetListViewProtocol?,
        prices: [ChainAssetId: PriceData],
        balances: [AssetBalance],
        chains: [ChainModel.Id: ChainModel],
        locks: [AssetLock],
        crowdloans: [ChainModel.Id: [CrowdloanContributionData]]
    )

    func showRecieveTokens(
        from view: AssetListViewProtocol?,
        state: AssetListInitState
    )

    func showSendTokens(
        from view: AssetListViewProtocol?,
        state: AssetListInitState
    )
}
