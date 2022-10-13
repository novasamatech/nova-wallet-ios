import UIKit

extension SliderLayer.Style {
    static let governance = SliderLayer.Style(
        firstColor: R.color.colorGreen15CF37()!,
        lastColor: R.color.colorRedFF3A69()!,
        zeroColor: R.color.colorWhite16()!,
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
            color: R.color.colorBlack72()!,
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
