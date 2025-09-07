import Foundation
import Foundation_iOS
import UIKit

protocol PayoutTimeViewModelFactoryProtocol {
    func timeLeftAttributedString(
        payoutEra: EraIndex,
        historyDepth: UInt32,
        eraCountdown: EraCountdown?,
        locale: Locale
    ) -> NSAttributedString
}

final class PayoutTimeViewModelFactory: PayoutTimeViewModelFactoryProtocol {
    private let timeFormatter: TimeFormatterProtocol
    private let normalTimelefColor: UIColor
    private let deadlineTimelefColor: UIColor

    init(
        timeFormatter: TimeFormatterProtocol,
        normalTimelefColor: UIColor = R.color.colorTextSecondary()!,
        deadlineTimelefColor: UIColor = R.color.colorTextNegative()!
    ) {
        self.timeFormatter = timeFormatter
        self.normalTimelefColor = normalTimelefColor
        self.deadlineTimelefColor = deadlineTimelefColor
    }

    func timeLeftAttributedString(
        payoutEra: EraIndex,
        historyDepth: UInt32,
        eraCountdown: EraCountdown?,
        locale: Locale
    ) -> NSAttributedString {
        guard let eraCountdown = eraCountdown else { return .init(string: "") }

        let eraCompletionTime = eraCountdown.timeIntervalTillSet(targetEra: payoutEra + historyDepth + 1)
        let daysLeft = eraCompletionTime.daysFromSeconds

        let timeLeftText: String = {
            if eraCompletionTime <= .leastNormalMagnitude {
                return R.string(preferredLanguages: locale.rLanguages).localizable.stakingPayoutExpired()
            }
            if daysLeft == 0 {
                let formattedTime = (try? timeFormatter.string(from: eraCompletionTime)) ?? ""
                return R.string(preferredLanguages: locale.rLanguages
                ).localizable.commonTimeLeftFormat(formattedTime)
            } else {
                return R.string(preferredLanguages: locale.rLanguages).localizable.commonDaysLeftFormat(format: daysLeft)
            }
        }()

        let erasPerDay = eraCountdown.eraTimeInterval.intervalsInDay
        let historyDepthDays = erasPerDay > 0 ? (historyDepth / 2) / UInt32(erasPerDay) : 0
        let textColor: UIColor = daysLeft < historyDepthDays ?
            deadlineTimelefColor : normalTimelefColor

        let attrubutedString = NSAttributedString(
            string: timeLeftText,
            attributes: [.foregroundColor: textColor]
        )
        return attrubutedString
    }
}
