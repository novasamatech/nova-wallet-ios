import Foundation

enum TextHeightCalculationContext {
    case banner(text: [String])
    case custom(text: [HeightCalculatableText])

    var calculatableText: [HeightCalculatableText] {
        switch self {
        case let .banner(rawText):
            createCalculatableText(
                rawText: rawText,
                params: TextHeightCalculationParams.createForBanners()
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
