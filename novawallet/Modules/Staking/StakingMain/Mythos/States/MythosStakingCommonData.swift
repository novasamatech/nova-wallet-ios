import Foundation

struct MythosStakingCommonData {
    let account: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let balance: AssetBalance?
    let frozenBalance: MythosStakingFrozenBalance?
    let price: PriceData?
    let stakingDetails: MythosStakingDetails?
    let collatorsInfo: MythosSessionCollators?
    let stakingDuration: MythosStakingDuration?
    let calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol?
    let blockNumber: BlockNumber?
    let currentSession: SessionIndex?
    let totalReward: TotalRewardItem?
    
    init(
        account: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        balance: AssetBalance? = nil,
        frozenBalance: MythosStakingFrozenBalance? = nil,
        price: PriceData? = nil,
        stakingDetails: MythosStakingDetails? = nil,
        collatorsInfo: MythosSessionCollators? = nil,
        stakingDuration: MythosStakingDuration? = nil,
        calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol? = nil,
        blockNumber: BlockNumber? = nil,
        currentSession: SessionIndex? = nil,
        totalReward: TotalRewardItem? = nil
    ) {
        self.account = account
        self.chainAsset = chainAsset
        self.balance = balance
        self.frozenBalance = frozenBalance
        self.price = price
        self.stakingDetails = stakingDetails
        self.collatorsInfo = collatorsInfo
        self.stakingDuration = stakingDuration
        self.calculatorEngine = calculatorEngine
        self.blockNumber = blockNumber
        self.currentSession = currentSession
        self.totalReward = totalReward
    }

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
    func byReplacing(assetBalance: AssetBalance?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(frozenBalance: MythosStakingFrozenBalance?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(price: PriceData?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(stakingDetails: MythosStakingDetails?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(collatorsInfo: MythosSessionCollators?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(stakingDuration: MythosStakingDuration?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(
        calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol?
    ) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(blockNumber: BlockNumber?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(currentSession: SessionIndex?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
    
    func byReplacing(totalReward: TotalRewardItem?) -> MythosStakingCommonData {
        MythosStakingCommonData(
            account: account,
            chainAsset: chainAsset,
            balance: balance,
            frozenBalance: frozenBalance,
            price: price,
            stakingDetails: stakingDetails,
            collatorsInfo: collatorsInfo,
            stakingDuration: stakingDuration,
            calculatorEngine: calculatorEngine,
            blockNumber: blockNumber,
            currentSession: currentSession,
            totalReward: totalReward
        )
    }
}
