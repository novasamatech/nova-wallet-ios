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

    var viewModel: SelectRampProvider.ViewModel.ProviderViewModel?

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

    func createCounterView(with text: String) -> UIView {
        let view = BorderedLabelView()

        view.snp.makeConstraints { make in
            make.size.equalTo(Constants.otherPaymentMethodsViewSize)
        }

        view.contentInsets = Constants.otherPaymentsMethodViewContentInsets

        view.titleLabel.apply(style: .semiboldCaps2Chip)
        view.titleLabel.textAlignment = .center
        view.backgroundView.apply(
            style: .roundedChips(radius: Constants.otherPaymentMethodsCornerRadius)
        )

        view.titleLabel.text = text

        return view
    }

    func createPaymentMethodView(with icon: UIImage) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = icon

        return imageView
    }
}

// MARK: Internal

extension RampProviderView {
    func bind(with model: SelectRampProvider.ViewModel.ProviderViewModel) {
        viewModel = model

        providerLogoImageView.image = model.logo
        descriptionLabel.text = model.descriptionText

        paymentMethodsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        model.fiatPaymentMethods.forEach { paymentMethod in
            let view: UIView = switch paymentMethod {
            case let .icon(image):
                createPaymentMethodView(with: image)
            case let .text(text):
                createCounterView(with: text)
            }

            paymentMethodsStack.addArrangedSubview(view)
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
        static let otherPaymentsMethodViewContentInsets = UIEdgeInsets(
            top: 1.5,
            left: 2.0,
            bottom: 1.5,
            right: 2.0
        )
        static let otherPaymentMethodsViewSize = CGSize(
            width: 24.0,
            height: 16.0
        )
        static let otherPaymentMethodsCornerRadius: CGFloat = 2.0
    }
}
