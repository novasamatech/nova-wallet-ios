import Foundation
import UIKit

struct HeightCalculatableText {
    let text: String
    let params: TextHeightCalculationParams
}

struct TextHeightCalculationParams {
    let availableWidth: CGFloat
    let font: UIFont
    let bottomInset: CGFloat
    let topInset: CGFloat
}

extension TextHeightCalculationParams {
    static func createForBanners(availableWidth: CGFloat) -> [TextHeightCalculationParams] {
        let title = TextHeightCalculationParams(
            availableWidth: availableWidth,
            font: .semiBoldBody,
            bottomInset: 8.0,
            topInset: .zero
        )
        let description = TextHeightCalculationParams(
            availableWidth: availableWidth,
            font: .caption1,
            bottomInset: .zero,
            topInset: .zero
        )

        return [title, description]
    }

    static func createForFeaturedBanners(availableWidth: CGFloat) -> [TextHeightCalculationParams] {
        let featuredWidth = availableWidth
            + BannerView.Constants.contentImageViewWidth
            - BannerView.Constants.featuredTextTrailingInset

        let title = TextHeightCalculationParams(
            availableWidth: featuredWidth,
            font: .semiBoldTitle3,
            bottomInset: BannerView.Constants.featuredTextSpacing,
            topInset: BannerView.Constants.featuredTextTopInset - BannerView.Constants.textContainerVerticalInset
        )
        let description = TextHeightCalculationParams(
            availableWidth: featuredWidth,
            font: .caption1,
            bottomInset: .zero,
            topInset: .zero
        )

        return [title, description]
    }
}
