import UIKit

extension UIFont {
    static var h1Title: UIFont { R.font.publicSansBold(size: 31)! }

    static var h2Title: UIFont { R.font.publicSansBold(size: 23)! }

    static var h3Title: UIFont { R.font.publicSansBold(size: 19)! }

    static var h4Title: UIFont { R.font.publicSansBold(size: 17)! }

    static var h5Title: UIFont { R.font.publicSansBold(size: 15)! }

    static var h6Title: UIFont { R.font.publicSansBold(size: 13)! }

    static var capsTitle: UIFont { R.font.publicSansBold(size: 11)! }

    static var p0Paragraph: UIFont { R.font.publicSansRegular(size: 17)! }

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

        let fontDescriptor = R.font.publicSansRegular(size: 17)!.fontDescriptor
            .addingAttributes([UIFontDescriptor.AttributeName.featureSettings: fontFeatures])

        return UIFont(descriptor: fontDescriptor, size: 17)
    }

    static var p1Paragraph: UIFont { R.font.publicSansRegular(size: 15)! }

    static var p2Paragraph: UIFont { R.font.publicSansRegular(size: 13)! }

    static var p3Paragraph: UIFont { R.font.publicSansSemiBold(size: 11)! }
}
