import Foundation

struct GiftsOnboardingViewModel {
    struct Step {
        let number: String
        let attributedDescription: NSAttributedString
    }

    let title: String
    let subtitle: String?
    let steps: [Step]
    let learnMoreTitle: String
    let actionTitle: String
}
