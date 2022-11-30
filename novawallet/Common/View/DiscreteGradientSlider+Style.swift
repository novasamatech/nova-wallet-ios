import UIKit

extension DiscreteGradientSlider {
    func applyConvictionDefaultStyle() {
        thumbImageView.image = R.image.iconSliderThumb()
        trackOverlayView.fillColor = R.color.colorVotingSliderBackground()!
        verticalSpacing = 5.0
        numberOfValues = 7
        titles = ["0.1x", "1x", "2x", "3x", "4x", "5x", "6x"]
        titleFont = .caption1

        applyConvictionActiveStyle()
    }

    func applyConvictionActiveStyle() {
        dotColor = R.color.colorVotingSliderIndicatorActive()!
        colors = [
            R.color.colorConvictionSliderText01x()!,
            R.color.colorConvictionSliderText1x()!,
            R.color.colorConvictionSliderText2x()!,
            R.color.colorConvictionSliderText3x()!,
            R.color.colorConvictionSliderText4x()!,
            R.color.colorConvictionSliderText5x()!,
            R.color.colorConvictionSliderText6x()!
        ]
    }

    func applyConvictionInactiveStyle() {
        dotColor = R.color.colorVotingSliderIndicatorInactive()!
        colors = [
            R.color.colorVotingSliderBackground()!
        ]
    }
}
