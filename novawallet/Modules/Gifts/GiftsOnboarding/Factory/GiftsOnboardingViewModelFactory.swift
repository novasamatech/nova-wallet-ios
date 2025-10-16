import Foundation
import UIKit

protocol GiftsOnboardingViewModelFactoryProtocol {
    func createViewModel(locale: Locale) -> GiftsOnboardingViewModel
}

final class GiftsOnboardingViewModelFactory {
    private let highlightedAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: R.color.colorTextPrimary()!,
        .font: UIFont.semiBoldBody
    ]

    private func createAttributedString(
        template: String,
        highlighted: String
    ) -> NSAttributedString {
        let decorator = AttributedReplacementStringDecorator(
            pattern: AttributedReplacementStringDecorator.marker,
            replacements: [highlighted],
            attributes: highlightedAttributes
        )

        return decorator.decorate(attributedString: NSAttributedString(string: template))
    }
}

extension GiftsOnboardingViewModelFactory: GiftsOnboardingViewModelFactoryProtocol {
    func createViewModel(locale: Locale) -> GiftsOnboardingViewModel {
        let languages = locale.rLanguages

        // Step 1
        let step1Template = R.string.localizable.giftsOnboardingStep1Template(
            AttributedReplacementStringDecorator.marker,
            preferredLanguages: languages
        )
        let step1Highlighted = R.string.localizable.giftsOnboardingStep1Highlighted(
            preferredLanguages: languages
        )
        let step1Attributed = createAttributedString(
            template: step1Template,
            highlighted: step1Highlighted
        )

        // Step 2
        let step2Template = R.string.localizable.giftsOnboardingStep2Template(
            AttributedReplacementStringDecorator.marker,
            preferredLanguages: languages
        )
        let step2Highlighted = R.string.localizable.giftsOnboardingStep2Highlighted(
            preferredLanguages: languages
        )
        let step2Attributed = createAttributedString(
            template: step2Template,
            highlighted: step2Highlighted
        )

        // Step 3
        let step3Template = R.string.localizable.giftsOnboardingStep3Template(
            AttributedReplacementStringDecorator.marker,
            preferredLanguages: languages
        )
        let step3Highlighted = R.string.localizable.giftsOnboardingStep3Highlighted(
            preferredLanguages: languages
        )
        let step3Attributed = createAttributedString(
            template: step3Template,
            highlighted: step3Highlighted
        )

        let steps: [GiftsOnboardingViewModel.Step] = [
            GiftsOnboardingViewModel.Step(number: "1", attributedDescription: step1Attributed),
            GiftsOnboardingViewModel.Step(number: "2", attributedDescription: step2Attributed),
            GiftsOnboardingViewModel.Step(number: "3", attributedDescription: step3Attributed)
        ]

        return GiftsOnboardingViewModel(
            title: R.string.localizable.giftsOnboardingTitle(preferredLanguages: languages),
            subtitle: R.string.localizable.giftsOnboardingSubtitle(preferredLanguages: languages),
            steps: steps,
            learnMoreTitle: R.string.localizable.commonLearnMore(preferredLanguages: languages),
            actionTitle: R.string.localizable.giftsActionCreateGift(preferredLanguages: languages)
        )
    }
}
