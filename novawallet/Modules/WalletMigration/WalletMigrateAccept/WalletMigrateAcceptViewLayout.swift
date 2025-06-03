import UIKit
import UIKit_iOS

final class WalletMigrateAcceptViewLayout: SCLoadableActionLayoutView, AdaptiveDesignable {
    let backgroundView: UIImageView = .create { imageView in
        imageView.image = R.image.novabgSplash()
        imageView.contentMode = .scaleAspectFill
    }

    let skipButton: RoundedButton = .create { button in
        button.applyAccessoryStyle()
    }

    let illustrationView: UIImageView = .create { imageView in
        imageView.image = R.image.imageSiriMigration()
        imageView.contentMode = .scaleAspectFit
    }

    let titleView: MultiValueView = .create { view in
        view.valueTop.apply(style: .boldLargePrimary)
        view.valueTop.textAlignment = .center
        view.valueTop.numberOfLines = 0
        view.valueBottom.apply(style: .regularBodySecondary)
        view.valueBottom.textAlignment = .center
        view.valueBottom.numberOfLines = 0
        view.spacing = Constants.titleValueSpacing
    }

    override func setupStyle() {
        super.setupStyle()

        genericActionView.actionButton.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        insertSubview(backgroundView, at: 0)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        stackView.layoutMargins = .init(
            top: Constants.illustrationTopOffset * designScaleRatio.height,
            left: Constants.horizontalInset,
            bottom: stackView.layoutMargins.bottom,
            right: Constants.horizontalInset
        )
        addArrangedSubview(illustrationView, spacingAfter: Constants.illustrationVerticalSpacing)
        addArrangedSubview(titleView, spacingAfter: Constants.titleVerticalSpacing)
    }
}

// MARK: - Constants

private extension WalletMigrateAcceptViewLayout {
    enum Constants {
        static let illustrationTopOffset: CGFloat = 48.0
        static let horizontalInset: CGFloat = 24.0
        static let titleVerticalSpacing: CGFloat = 24.0
        static let titleValueSpacing: CGFloat = 8.0
        static let illustrationVerticalSpacing: CGFloat = 8.0
    }
}
