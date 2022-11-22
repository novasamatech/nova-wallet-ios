import SoraUI

extension RoundedView.Style {
    static let nft = RoundedView.Style(
        shadow: .init(
            shadowOpacity: 1,
            shadowColor: UIColor.black.withAlphaComponent(0.56),
            shadowRadius: 4,
            shadowOffset: .init(width: 4, height: 0)
        ),
        strokeWidth: 0,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 8, corners: .allCorners)
    )

    static let lastNft = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 8, corners: .allCorners)
    )
}
