import Foundation
import UIKit

protocol GiftsOnboardingViewModelFactoryProtocol {
    func createViewModel(locale: Locale) -> GiftsOnboardingViewModel
}

final class GiftsOnboardingViewModelFactory {
    private let highlightedAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: R.color.colorTextPrimary()!,
        .font: UIFont.regularBody
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

        let step1Template = R.string(
            preferredLanguages: languages
        ).localizable.giftsOnboardingStep1Template(
            AttributedReplacementStringDecorator.marker
        )
        let step1Highlighted = R.string(
            preferredLanguages: languages
        ).localizable.giftsOnboardingStep1Highlighted()
        let step1Attributed = createAttributedString(
            template: step1Template,
            highlighted: step1Highlighted
        )

        let step2Template = R.string(
            preferredLanguages: languages
        ).localizable.giftsOnboardingStep2Template(
            AttributedReplacementStringDecorator.marker
        )
        let step2Highlighted = R.string(
            preferredLanguages: languages
        ).localizable.giftsOnboardingStep2Highlighted()
        let step2Attributed = createAttributedString(
            template: step2Template,
            highlighted: step2Highlighted
        )

        let step3Template = R.string(
            preferredLanguages: languages
        ).localizable.giftsOnboardingStep3Template(
            AttributedReplacementStringDecorator.marker
        )
        let step3Highlighted = R.string(
            preferredLanguages: languages
        ).localizable.giftsOnboardingStep3Highlighted()
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
            steps: steps,
            actionTitle: R.string(preferredLanguages: languages).localizable.giftsActionCreateGift(),
            locale: locale
        )
    }
}
