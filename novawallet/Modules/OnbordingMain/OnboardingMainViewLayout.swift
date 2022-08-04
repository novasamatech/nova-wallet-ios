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

    // swiftlint:disable:next function_body_length
    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in make.edges.equalToSuperview() }

        let logoCenterMultiplier: CGFloat

        if isAdaptiveHeightDecreased {
            logoCenterMultiplier = 0.64 * designScaleRatio.height
        } else {
            logoCenterMultiplier = 0.64
        }

        addSubview(logo)
        logo.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(91.0)
            make.centerY.equalToSuperview().multipliedBy(logoCenterMultiplier)
        }

        logo.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20.0)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16.0)
        }

        let bottomOffset = 16.0
        let topOffset = 24.0
        let buttonsBaseWidth = 335.0
        let buttonsWidth: CGFloat

        if isAdaptiveWidthDecreased {
            buttonsWidth = buttonsBaseWidth * designScaleRatio.width
        } else {
            buttonsWidth = buttonsBaseWidth
        }

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
            make.top.greaterThanOrEqualTo(logo.snp.bottom).offset(topOffset)
            make.centerX.equalToSuperview()
            make.width.equalTo(buttonsWidth)
        }
    }
}
