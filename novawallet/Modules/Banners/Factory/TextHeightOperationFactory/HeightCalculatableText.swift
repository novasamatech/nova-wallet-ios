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
}
