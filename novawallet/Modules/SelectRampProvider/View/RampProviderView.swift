import Foundation
import UIKit

class RampProviderView: UIView {
    let providerLogoImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let paymentMethodsStack: UIStackView = .create { view in
        view.spacing = Constants.stackSpacing
        view.axis = .horizontal
    }

    let descriptionLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.numberOfLines = 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension RampProviderView {
    func setupLayout() {
        addSubview(providerLogoImageView)
        addSubview(paymentMethodsStack)
        addSubview(descriptionLabel)

        providerLogoImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.providerLogoImageSize)
            make.leading.top.equalToSuperview()
        }
        paymentMethodsStack.snp.makeConstraints { make in
            make.centerY.equalTo(providerLogoImageView)
            make.trailing.equalToSuperview()
        }
        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(providerLogoImageView)
            make.top.equalTo(providerLogoImageView.snp.bottom).inset(-Constants.descriptionTopInset)
            make.bottom.equalToSuperview()
        }
    }
}

// MARK: Internal

extension RampProviderView {
    func bind(with model: SelectRampProvider.ViewModel.ProviderViewModel) {
        providerLogoImageView.image = model.logo
        descriptionLabel.text = model.descriptionText

        paymentMethodsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        model.fiatPaymentMethods.forEach { paymentMethod in
            if let logoIcon = paymentMethod.icon {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFit
                imageView.image = logoIcon
                paymentMethodsStack.addArrangedSubview(imageView)
            } else if let text = paymentMethod.text {
                print(text)
            }
        }
    }
}

// MARK: Constants

private extension RampProviderView {
    enum Constants {
        static let providerLogoImageSize = CGSize(
            width: 106.0,
            height: 24.0
        )
        static let paymentMethodLogoImageSize = CGSize(
            width: 24.0,
            height: 16.0
        )
        static let stackSpacing: CGFloat = 6.0
        static let descriptionTopInset: CGFloat = 12.0
    }
}
