import Foundation
import Foundation_iOS

extension NumberFormatter {
    static var shopRaise: NumberFormatter {
        let formatter = NumberFormatter.percent
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .down
        return formatter
    }
}
