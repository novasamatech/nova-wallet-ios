import UIKit
import SoraUI

final class OnboardingMainViewLayout: UIView, AdaptiveDesignable {
    let backgroundView: UIImageView = {
        let imageView = UIImageView(image: R.image.novabgSplash())
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    let logo: UIImageView = {
        let imageView = UIImageView(image: R.image.logo()!)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let termsLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let createButton: ButtonLargeControl = {
        let button = ButtonLargeControl()
        button.style = .primary
        button.iconView.image = R.image.iconPlusFilled()
        return button
    }()

    let importButton: ButtonLargeControl = {
        let button = ButtonLargeControl()
        button.style = .secondary
        button.iconView.image = R.image.iconImportWallet()
        return button
    }()

    let hardwareButton: ButtonLargeControl = {
        let button = ButtonLargeControl()
        button.style = .secondary
        button.iconView.image = R.image.iconHardwareWallet()
        return button
    }()

    let watchOnlyButton: ButtonLargeControl = {
        let button = ButtonLargeControl()
        button.style = .secondary
        button.iconView.image = R.image.iconWatchOnly()
        return button
    }()

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
        }

        logo.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20.0)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16.0)
        }

        let bottomOffset = 16.0
        let buttonsBaseWidth = 335.0

        let buttonWidthMultiplier = isAdaptiveWidthDecreased ? designScaleRatio.width : 1.0
        let buttonsWidth: CGFloat = buttonsBaseWidth * buttonWidthMultiplier

        addSubview(watchOnlyButton)
        watchOnlyButton.snp.makeConstraints { make in
            make.bottom.equalTo(termsLabel.snp.top).offset(-bottomOffset)
            make.centerX.equalToSuperview()
            make.width.equalTo(buttonsWidth)
        }

        addSubview(hardwareButton)
        hardwareButton.snp.makeConstraints { make in
            make.bottom.equalTo(watchOnlyButton.snp.top).offset(-10)
            make.centerX.equalToSuperview()
            make.width.equalTo(buttonsWidth)
        }

        addSubview(importButton)
        importButton.snp.makeConstraints { make in
            make.bottom.equalTo(hardwareButton.snp.top).offset(-10.0)
            make.centerX.equalToSuperview()
            make.width.equalTo(buttonsWidth)
        }

        addSubview(createButton)
        createButton.snp.makeConstraints { make in
            make.bottom.equalTo(importButton.snp.top).offset(-10.0)
            make.centerX.equalToSuperview()
            make.width.equalTo(buttonsWidth)
        }
    }
}
