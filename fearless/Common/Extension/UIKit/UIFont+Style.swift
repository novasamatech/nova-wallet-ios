import UIKit

extension UIFont {
    static var h1Title: UIFont { R.font.publicSansBold(size: 30)! }

    static var h2Title: UIFont { R.font.publicSansBold(size: 22)! }

    static var h3Title: UIFont { R.font.publicSansBold(size: 18)! }

    static var h4Title: UIFont { R.font.publicSansBold(size: 16)! }

    static var h5Title: UIFont { R.font.publicSansBold(size: 14)! }

    static var h6Title: UIFont { R.font.publicSansBold(size: 12)! }

    static var capsTitle: UIFont { R.font.publicSansBold(size: 10)! }

    static var p0Paragraph: UIFont { R.font.publicSansRegular(size: 16)! }

    static var p0Digits: UIFont {
        let fontFeatures = [
            [
                UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector
            ],

            [
                UIFontDescriptor.FeatureKey.featureIdentifier: kNumberCaseType,
                UIFontDescriptor.FeatureKey.typeIdentifier: kUpperCaseNumbersSelector
            ]
        ]

        let fontDescriptor = R.font.publicSansRegular(size: 16)!.fontDescriptor
            .addingAttributes([UIFontDescriptor.AttributeName.featureSettings: fontFeatures])

        return UIFont(descriptor: fontDescriptor, size: 16)
    }

    static var p1Paragraph: UIFont { R.font.publicSansRegular(size: 14)! }

    static var p2Paragraph: UIFont { R.font.publicSansRegular(size: 12)! }

    static var p3Paragraph: UIFont { R.font.publicSansSemiBold(size: 10)! }
}
