import UIKit

final class WalletMigrateAcceptViewLayout: SCLoadableActionLayoutView {
    let backgroundView: UIImageView = .create { imageView in
        imageView.image = R.image.novabgSplash()
        imageView.contentMode = .scaleAspectFill
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
        view.spacing = 8
    }

    override func setupStyle() {
        super.setupStyle()

        genericActionView.actionButton.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        stackView.layoutMargins = .init(
            top: stackView.layoutMargins.top,
            left: 24.0,
            bottom: stackView.layoutMargins.bottom,
            right: 24.0
        )
        addArrangedSubview(illustrationView, spacingAfter: 8.0)
        addArrangedSubview(titleView, spacingAfter: 24.0)
    }
}
