import Foundation
import BigInt

extension ParachainStaking {
    struct CommonData {
        let account: MetaChainAccountResponse?
        let chainAsset: ChainAsset?
        let balance: AssetBalance?
        let price: PriceData?
        let networkInfo: ParachainStaking.NetworkInfo?
        let calculatorEngine: ParaStakingRewardCalculatorEngineProtocol?
        let collatorsInfo: SelectedRoundCollators?
    }
}

extension ParachainStaking.CommonData {
    static var empty: ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: nil,
            chainAsset: nil,
            balance: nil,
            price: nil,
            networkInfo: nil,
            calculatorEngine: nil,
            collatorsInfo: nil
        )
    }

    func byReplacing(account: MetaChainAccountResponse?) -> ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            networkInfo: networkInfo,
            calculatorEngine: calculatorEngine,
            collatorsInfo: collatorsInfo
        )
    }

    func byReplacing(chainAsset: ChainAsset?) -> ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            networkInfo: networkInfo,
            calculatorEngine: calculatorEngine,
            collatorsInfo: collatorsInfo
        )
    }

    func byReplacing(balance: AssetBalance?) -> ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            networkInfo: networkInfo,
            calculatorEngine: calculatorEngine,
            collatorsInfo: collatorsInfo
        )
    }

    func byReplacing(price: PriceData?) -> ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            networkInfo: networkInfo,
            calculatorEngine: calculatorEngine,
            collatorsInfo: collatorsInfo
        )
    }

    func byReplacing(networkInfo: ParachainStaking.NetworkInfo?) -> ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            networkInfo: networkInfo,
            calculatorEngine: calculatorEngine,
            collatorsInfo: collatorsInfo
        )
    }

    func byReplacing(
        calculatorEngine: ParaStakingRewardCalculatorEngineProtocol?
    ) -> ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            networkInfo: networkInfo,
            calculatorEngine: calculatorEngine,
            collatorsInfo: collatorsInfo
        )
    }

    func byReplacing(
        collatorsInfo: SelectedRoundCollators?
    ) -> ParachainStaking.CommonData {
        ParachainStaking.CommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            networkInfo: networkInfo,
            calculatorEngine: calculatorEngine,
            collatorsInfo: collatorsInfo
        )
    }
}
