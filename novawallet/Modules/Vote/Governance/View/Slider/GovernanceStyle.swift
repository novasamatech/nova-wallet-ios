import UIKit

extension SliderLayer.Style {
    static let governance = SliderLayer.Style(
        firstColor: UIColor(red: 0.081, green: 0.812, blue: 0.215, alpha: 1),
        lastColor: UIColor(red: 0.749, green: 0.216, blue: 0.345, alpha: 1),
        cornerRadius: 4,
        dividerSpace: 6
    )
}

extension SegmentedSliderView.ThumbStyle {
    static let governance = SegmentedSliderView.ThumbStyle(
        color: .white,
        cornerRadius: 8,
        width: 3,
        height: nil,
        shadow: .init(
            color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.72),
            opacity: 1,
            offset: .zero,
            radius: 8
        )
    )
}

extension SegmentedSliderView.Style {
    static let governance = SegmentedSliderView.Style(
        lineInsets: .init(top: 3, left: 0, bottom: 3, right: 0),
        sliderStyle: .governance,
        thumbStyle: .governance
    )
}
