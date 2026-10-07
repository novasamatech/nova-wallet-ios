import Foundation
import UIKit

enum TextHeightCalculationContext {
    case banner(text: [String], availableWidth: CGFloat)
    case featuredBanner(text: [String], availableWidth: CGFloat)
    case custom(text: [HeightCalculatableText])

    var calculatableText: [HeightCalculatableText] {
        switch self {
        case let .banner(rawText, availableWidth):
            createCalculatableText(
                rawText: rawText,
                params: TextHeightCalculationParams.createForBanners(availableWidth: availableWidth)
            )
        case let .featuredBanner(rawText, availableWidth):
            createCalculatableText(
                rawText: rawText,
                params: TextHeightCalculationParams.createForFeaturedBanners(availableWidth: availableWidth)
            )
        case let .custom(text): text
        }
    }

    private func createCalculatableText(
        rawText: [String],
        params: [TextHeightCalculationParams]
    ) -> [HeightCalculatableText] {
        zip(rawText, params).map {
            HeightCalculatableText(
                text: $0.0,
                params: $0.1
            )
        }
    }
}

extension TextHeightCalculationContext {
    var estimatedHeight: Float {
        var height: Float = 0.0

        calculatableText.forEach { string in
            height
                += Float(string.text.estimateHeight(
                    for: string.params.font,
                    width: string.params.availableWidth
                ))
                + Float(string.params.topInset)
                + Float(string.params.bottomInset)
        }

        return height
    }
}
