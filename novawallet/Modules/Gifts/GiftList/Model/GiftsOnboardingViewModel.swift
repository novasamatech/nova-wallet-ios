import Foundation

struct GiftsOnboardingViewModel {
    struct Step {
        let number: String
        let attributedDescription: NSAttributedString
    }

    let steps: [Step]
    let actionTitle: String
    let locale: Locale
}
