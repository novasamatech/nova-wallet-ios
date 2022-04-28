import Foundation
import UIKit

extension AssetIconView {
    static func defaultView(with icon: UIImage?, iconSize: CGSize, insets: UIEdgeInsets) -> AssetIconView {
        let view = AssetIconView()
        view.backgroundView.cornerRadius = iconSize.height / 2.0
        view.backgroundView.fillColor = R.color.colorWhite16()!
        view.backgroundView.highlightedFillColor = R.color.colorWhite16()!
        view.backgroundView.strokeColor = R.color.colorWhite8()!
        view.contentInsets = insets
        view.imageView.tintColor = R.color.colorTransparentText()

        if let icon = icon?.withRenderingMode(.alwaysOriginal) {
            let viewModel = StaticImageViewModel(image: icon)
            let size = CGSize(
                width: iconSize.width - insets.left - insets.right,
                height: iconSize.height - insets.top - insets.bottom
            )

            view.bind(viewModel: viewModel, size: size)
        }

        return view
    }

    static func rewards(with iconSize: CGSize, insets: UIEdgeInsets) -> AssetIconView {
        defaultView(
            with: R.image.iconRewardOperation(),
            iconSize: iconSize,
            insets: insets
        )
    }

    static func cellRewards() -> AssetIconView {
        rewards(
            with: CGSize(width: 36.0, height: 36.0),
            insets: UIEdgeInsets(top: 6.0, left: 6.0, bottom: 6.0, right: 6.0)
        )
    }

    static func standaloneRewards() -> AssetIconView {
        rewards(
            with: CGSize(width: 64.0, height: 64.0),
            insets: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        )
    }
}
