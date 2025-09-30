import Foundation

struct EraCountdown {
    let activeEra: Staking.EraIndex
    let currentEra: Staking.EraIndex
    let eraLength: SessionIndex
    let sessionLength: SessionIndex
    let activeEraStartSessionIndex: SessionIndex
    let currentSessionIndex: SessionIndex
    let currentEpochIndex: EpochIndex
    let currentSlot: Slot
    let genesisSlot: Slot
    let blockCreationTime: Moment

    // when the timeline chain differs from current on we might
    // add some blocks delay
    let eraDelayInBlocks: UInt32
    let createdAtDate: Date

    var blockTimeInSeconds: TimeInterval {
        TimeInterval(blockCreationTime).seconds
    }

    var eraTimeInterval: TimeInterval {
        let eraLengthInSlots = sessionLength * eraLength
        return TimeInterval(eraLengthInSlots) * blockTimeInSeconds
    }

    func timeIntervalTillStart(targetEra: Staking.EraIndex) -> TimeInterval {
        guard targetEra > activeEra else { return 0 }

        let numberOfSlotsPerSession = UInt64(sessionLength)
        let currentSessionIndexInt = UInt64(currentSessionIndex)
        let eraLengthInSlots = UInt64(sessionLength * eraLength)

        /*
         * Substrate has an assumption that Babe epoch duration is the same as session length.
         * But this doesn't mean that current epoch equals to current session.
         */
        let epochStartSlot = currentEpochIndex * numberOfSlotsPerSession + genesisSlot
        let sessionProgress = currentSlot >= epochStartSlot ? currentSlot - epochStartSlot : 0
        let eraProgress = (currentSessionIndexInt - UInt64(activeEraStartSessionIndex)) *
            numberOfSlotsPerSession + sessionProgress

        guard eraLengthInSlots >= eraProgress else {
            return 0
        }

        let eraRemained = TimeInterval(eraLengthInSlots - eraProgress)
        let eraRemainedTimeInterval = eraRemained * blockTimeInSeconds

        let datesTimeinterval = Date().timeIntervalSince(createdAtDate)
        let activeEraRemainedTime = eraRemainedTimeInterval - datesTimeinterval

        let distanceBetweenEras = TimeInterval(targetEra - (activeEra + 1))
        let targetEraDuration = distanceBetweenEras * TimeInterval(eraLengthInSlots) * blockTimeInSeconds

        let eraDelay = TimeInterval(eraDelayInBlocks) * blockTimeInSeconds

        return max(0.0, targetEraDuration + activeEraRemainedTime + eraDelay)
    }

    func timeIntervalTillNextActiveEraStart() -> TimeInterval {
        timeIntervalTillStart(targetEra: activeEra + 1)
    }

    func timeIntervalTillSet(targetEra: Staking.EraIndex) -> TimeInterval {
        let sessionDuration = TimeInterval(sessionLength) * blockTimeInSeconds
        let tillEraStart = timeIntervalTillStart(targetEra: targetEra)

        return max(tillEraStart - sessionDuration, 0.0)
    }

    func timeIntervalTillNextCurrentEraSet() -> TimeInterval {
        timeIntervalTillSet(targetEra: currentEra + 1)
    }
}
