import UIKit
import UIKit_iOS

final class OnboardingMainViewLayout: UIView, AdaptiveDesignable {
    let backgroundView: UIImageView = .create { imageView in
        imageView.image = R.image.novabgSplash()
        imageView.contentMode = .scaleAspectFill
    }

    let logo: UIImageView = .create { imageView in
        imageView.image = R.image.logo()
        imageView.contentMode = .scaleAspectFit
    }

    let termsLabel: UILabel = .create { label in
        label.isUserInteractionEnabled = true
        label.numberOfLines = 0
        label.textAlignment = .center
    }

    let createButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    let importButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }

        let logoHorizontalInset: CGFloat = 40
        let logoBottomMultiplier: CGFloat = 0.5

        addSubview(logo)
        logo.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().offset(logoHorizontalInset)
            make.trailing.lessThanOrEqualToSuperview().offset(-logoHorizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).multipliedBy(logoBottomMultiplier)
            make.centerX.equalToSuperview()
        }

        logo.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16)
        }

        addSubview(importButton)
        importButton.snp.makeConstraints { make in
            make.bottom.equalTo(termsLabel.snp.top).offset(-24)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(createButton)
        createButton.snp.makeConstraints { make in
            make.bottom.equalTo(importButton.snp.top).offset(-12)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
