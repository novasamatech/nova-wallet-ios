import Foundation

extension IconDetailsView {
    static func hint() -> IconDetailsView {
        let view = IconDetailsView()
        view.iconWidth = 16.0
        view.stackView.alignment = .top
        view.detailsLabel.font = .caption1
        view.detailsLabel.textColor = R.color.colorTransparentText()
        view.imageView.image = R.image.iconStarGray16()
        return view
    }
}
