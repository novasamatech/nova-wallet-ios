import Foundation

protocol EraCountdownDisplayProtocol {
    var activeEra: Staking.EraIndex { get }

    func timeIntervalTillStart(targetEra: Staking.EraIndex) -> TimeInterval
    func timeIntervalTillNextActiveEraStart() -> TimeInterval
}

extension EraCountdown: EraCountdownDisplayProtocol {}
