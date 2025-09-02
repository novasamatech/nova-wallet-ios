import UIKit_iOS

extension RoundedView.Style {
    static let shadowedNft = RoundedView.Style(
        shadow: .init(
            shadowOpacity: 1,
            shadowColor: R.color.colorNftStackShadow()!,
            shadowRadius: 4,
            shadowOffset: .init(width: 4, height: 0)
        ),
        strokeWidth: 0,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 8, corners: .allCorners)
    )

    static let nft = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 8, corners: .allCorners)
    )
}
