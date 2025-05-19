import Foundation
import UIKit_iOS

extension RoundedView.Style {
    static var polkadotPay: RoundedView.Style {
        RoundedView.Style(
            shadow: .init(
                shadowOpacity: 1,
                shadowColor: R.color.colorChipBackgroundShadow()!,
                shadowRadius: 8,
                shadowOffset: CGSize(width: 0, height: 2)
            ),
            strokeWidth: 0,
            strokeColor: nil,
            highlightedStrokeColor: nil,
            fillColor: R.color.colorPolkadotPayBackground()!,
            highlightedFillColor: R.color.colorPolkadotPayBackground()!,
            rounding: .init(radius: 7, corners: .allCorners)
        )
    }
}
