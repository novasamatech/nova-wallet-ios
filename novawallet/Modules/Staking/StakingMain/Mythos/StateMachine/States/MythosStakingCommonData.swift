import Foundation

struct MythosStakingCommonData {
    let account: MetaChainAccountResponse?
    let chainAsset: ChainAsset?
    let balance: AssetBalance?
    let price: PriceData?
    let collatorsInfo: MythosSessionCollators?
    let stakingDuration: MythosStakingDuration?
    let calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol?
    let blockNumber: BlockNumber?
    let currentSession: SessionIndex?
    let totalReward: TotalRewardItem?
    let claimableRewards: MythosStakingClaimableRewards?

    var roundCountdown: ChainSessionCountdown? {
        if
            let blockNumber,
            let currentSession,
            let stakingDuration {
            return ChainSessionCountdown(
                currentSession: currentSession,
                info: stakingDuration.sessionInfo,
                blockTime: stakingDuration.block,
                currentBlock: blockNumber,
                createdAtDate: Date()
            )
        } else {
            return nil
        }
    }
}

extension MythosStakingCommonData {
    static var empty: MythosStakingCommonData {
        MythosStakingCommonData(
            account: nil,
            chainAsset: nil,
            balance: nil,
            price: nil,
            collatorsInfo: nil,
            stakingDuration: nil,
            calculatorEngine: nil,
            blockNumber: nil,
            currentSession: nil,
            totalReward: nil,
            claimableRewards: nil
        )
    }

    func byReplacing(account: MetaChainAccountResponse?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(chainAsset: ChainAsset?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(balance: AssetBalance?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(price: PriceData?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(collatorsInfo: MythosSessionCollators?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(stakingDuration: MythosStakingDuration?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(
        calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol?
    ) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(blockNumber: BlockNumber?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(currentSession: SessionIndex?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(totalReward: TotalRewardItem?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }

    func byReplacing(claimableRewards: MythosStakingClaimableRewards?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            price: price,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward,
            claimableRewards: claimableRewards
        )
    }
}
