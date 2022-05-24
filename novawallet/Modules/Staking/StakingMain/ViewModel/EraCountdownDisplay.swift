import Foundation

protocol EraCountdownDisplayProtocol {
    var activeEra: EraIndex { get }

    func timeIntervalTillStart(targetEra: EraIndex) -> TimeInterval
    func timeIntervalTillNextActiveEraStart() -> TimeInterval
}

extension EraCountdown: EraCountdownDisplayProtocol {}
