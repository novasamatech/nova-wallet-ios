import Foundation
import BigInt

struct StakingStateCommonData {
    let address: String?
    let chainAsset: ChainAsset?
    let accountBalance: AssetBalance?
    let price: PriceData?
    let calculatorEngine: RewardCalculatorEngineProtocol?
    let eraStakersInfo: EraStakersInfo?
    let minStake: BigUInt?
    let maxNominatorsPerValidator: UInt32?
    let minNominatorBond: BigUInt?
    let counterForNominators: UInt32?
    let maxNominatorsCount: UInt32?
    let bagListSize: UInt32?
    let bagListScoreFactor: BigUInt?
    let eraCountdown: EraCountdown?
    let totalRewardFilter: StakingRewardFiltersPeriod?
}

extension StakingStateCommonData {
    static var empty: StakingStateCommonData {
        StakingStateCommonData(
            address: nil,
            chainAsset: nil,
            accountBalance: nil,
            price: nil,
            calculatorEngine: nil,
            eraStakersInfo: nil,
            minStake: nil,
            maxNominatorsPerValidator: nil,
            minNominatorBond: nil,
            counterForNominators: nil,
            maxNominatorsCount: nil,
            bagListSize: nil,
            bagListScoreFactor: nil,
            eraCountdown: nil,
            totalRewardFilter: nil
        )
    }

    func byReplacing(address: String?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(chainAsset: ChainAsset?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(accountBalance: AssetBalance?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(price: PriceData?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(calculatorEngine: RewardCalculatorEngineProtocol?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(eraStakersInfo: EraStakersInfo?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(minStake: BigUInt?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(maxNominatorsPerValidator: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(minNominatorBond: BigUInt?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(counterForNominators: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(maxNominatorsCount: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(bagListSize: UInt32?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(bagListScoreFactor: BigUInt?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(eraCountdown: EraCountdown?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }

    func byReplacing(totalRewardFilter: StakingRewardFiltersPeriod?) -> StakingStateCommonData {
        StakingStateCommonData(
            address: address,
            chainAsset: chainAsset,
            accountBalance: accountBalance,
            price: price,
            calculatorEngine: calculatorEngine,
            eraStakersInfo: eraStakersInfo,
            minStake: minStake,
            maxNominatorsPerValidator: maxNominatorsPerValidator,
            minNominatorBond: minNominatorBond,
            counterForNominators: counterForNominators,
            maxNominatorsCount: maxNominatorsCount,
            bagListSize: bagListSize,
            bagListScoreFactor: bagListScoreFactor,
            eraCountdown: eraCountdown,
            totalRewardFilter: totalRewardFilter
        )
    }
}
