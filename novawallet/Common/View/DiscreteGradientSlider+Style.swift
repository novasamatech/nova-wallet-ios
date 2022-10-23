import UIKit

extension DiscreteGradientSlider {
    func applyConvictionDefaultStyle() {
        thumbImageView.image = R.image.iconSliderThumb()
        trackOverlayView.fillColor = R.color.colorSliderOverlay()!
        verticalSpacing = 5.0
        dotColor = R.color.colorBlack48()!
        numberOfValues = 7
        titles = ["0.1x", "1x", "2x", "3x", "4x", "5x", "6x"]
        titleFont = .caption1

        applyConvictionActiveStyle()
    }

    func applyConvictionActiveStyle() {
        colors = [
            UIColor(hex: "#1DE4FF")!,
            UIColor(hex: "#1AD1FF")!,
            UIColor(hex: "#1EB3FF")!,
            UIColor(hex: "#2194FF")!,
            UIColor(hex: "#7471FF")!,
            UIColor(hex: "#DF00FF")!,
            UIColor(hex: "#FF0087")!
        ]
    }

    func applyConvictionInactiveStyle() {
        colors = [
            R.color.colorWhite32()!
        ]
    }
}
