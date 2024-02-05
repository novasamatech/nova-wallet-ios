import Foundation
import BigInt

struct StakingStateCommonData {
    private(set) var address: String?
    private(set) var chainAsset: ChainAsset?
    private(set) var accountBalance: AssetBalance?
    private(set) var price: PriceData?
    private(set) var calculatorEngine: RewardCalculatorEngineProtocol?
    private(set) var eraStakersInfo: EraStakersInfo?
    private(set) var minStake: BigUInt?
    private(set) var maxNominatorsPerValidator: UInt32?
    private(set) var minNominatorBond: BigUInt?
    private(set) var counterForNominators: UInt32?
    private(set) var maxNominatorsCount: UInt32?
    private(set) var bagListSize: UInt32?
    private(set) var bagListScoreFactor: BigUInt?
    private(set) var eraCountdown: EraCountdown?
    private(set) var totalRewardFilter: StakingRewardFiltersPeriod?
    private(set) var proxy: UncertainStorage<ProxyDefinition?>
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
            totalRewardFilter: nil,
            proxy: .undefined
        )
    }

    func byReplacing(address: String?) -> StakingStateCommonData {
        replace {
            $0.address = address
        }
    }

    func byReplacing(chainAsset: ChainAsset?) -> StakingStateCommonData {
        replace {
            $0.chainAsset = chainAsset
        }
    }

    func byReplacing(accountBalance: AssetBalance?) -> StakingStateCommonData {
        replace {
            $0.accountBalance = accountBalance
        }
    }

    func byReplacing(price: PriceData?) -> StakingStateCommonData {
        replace {
            $0.price = price
        }
    }

    func byReplacing(calculatorEngine: RewardCalculatorEngineProtocol?) -> StakingStateCommonData {
        replace {
            $0.calculatorEngine = calculatorEngine
        }
    }

    func byReplacing(eraStakersInfo: EraStakersInfo?) -> StakingStateCommonData {
        replace {
            $0.eraStakersInfo = eraStakersInfo
        }
    }

    func byReplacing(minStake: BigUInt?) -> StakingStateCommonData {
        replace {
            $0.minStake = minStake
        }
    }

    func byReplacing(maxNominatorsPerValidator: UInt32?) -> StakingStateCommonData {
        replace {
            $0.maxNominatorsPerValidator = maxNominatorsPerValidator
        }
    }

    func byReplacing(minNominatorBond: BigUInt?) -> StakingStateCommonData {
        replace {
            $0.minNominatorBond = minNominatorBond
        }
    }

    func byReplacing(counterForNominators: UInt32?) -> StakingStateCommonData {
        replace {
            $0.counterForNominators = counterForNominators
        }
    }

    func byReplacing(maxNominatorsCount: UInt32?) -> StakingStateCommonData {
        replace {
            $0.maxNominatorsCount = maxNominatorsCount
        }
    }

    func byReplacing(bagListSize: UInt32?) -> StakingStateCommonData {
        replace {
            $0.bagListSize = bagListSize
        }
    }

    func byReplacing(bagListScoreFactor: BigUInt?) -> StakingStateCommonData {
        replace {
            $0.bagListScoreFactor = bagListScoreFactor
        }
    }

    func byReplacing(eraCountdown: EraCountdown?) -> StakingStateCommonData {
        replace {
            $0.eraCountdown = eraCountdown
        }
    }

    func byReplacing(totalRewardFilter: StakingRewardFiltersPeriod?) -> StakingStateCommonData {
        replace {
            $0.totalRewardFilter = totalRewardFilter
        }
    }

    func byReplacing(proxy: ProxyDefinition?) -> StakingStateCommonData {
        replace {
            $0.proxy = .defined(proxy)
        }
    }

    private func replace(builder: (inout StakingStateCommonData) -> Void) -> StakingStateCommonData {
        var data = self
        builder(&data)
        return data
    }
}
