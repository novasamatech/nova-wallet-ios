import Foundation
import BigInt

protocol StakingMainViewModelFactoryProtocol {
    func createMainViewModel(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        balance: BigUInt?
    ) -> StakingMainViewModel
}

final class StakingMainViewModelFactory: StakingMainViewModelFactoryProtocol {
    private var chainAsset: ChainAsset?
    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?

    private func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory, self.chainAsset == chainAsset {
            return factory
        }

        let factory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        self.chainAsset = chainAsset
        balanceViewModelFactory = factory

        return factory
    }

    func createMainViewModel(
        from accountId: AccountId,
        chainAsset: ChainAsset,
        balance: BigUInt?
    ) -> StakingMainViewModel {
        let displayInfo = chainAsset.assetDisplayInfo

        let decimalBalance = Decimal.fromSubstrateAmount(
            balance ?? 0,
            precision: displayInfo.assetPrecision
        ) ?? 0.0

        let balanceViewModel = getBalanceViewModelFactory(for: chainAsset)
            .amountFromValue(decimalBalance)

        let imageViewModel = chainAsset.assetDisplayInfo.icon.map {
            RemoteImageViewModel(url: $0)
        }

        return StakingMainViewModel(
            accountId: accountId,
            chainName: chainAsset.chain.name,
            assetName: chainAsset.asset.name ?? chainAsset.chain.name,
            assetIcon: imageViewModel,
            balanceViewModel: balanceViewModel
        )
    }
}
