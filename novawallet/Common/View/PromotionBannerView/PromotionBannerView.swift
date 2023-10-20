import UIKit
import SoraUI

protocol PromotionBannerViewDelegate: AnyObject {
    func promotionBannerDidRequestClose(view: PromotionBannerView)
}

final class PromotionBannerView: UIView {
    let backgroundView = UIImageView()

    let titleLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
    }

    let detailsLabel: UILabel = .create { label in
        label.apply(style: .footnotePrimary)
        label.numberOfLines = 0
    }

    let iconImageView = UIImageView()

    let closeButton: RoundedButton = .create { button in
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCloseWithBg()!
    }

    weak var delegate: PromotionBannerViewDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configureHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureHandlers() {
        closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    @objc func actionClose() {
        delegate?.promotionBannerDidRequestClose(view: self)
    }

    private func setupLayout() {
        addSubview(backgroundView)

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(24.0)
            make.centerY.equalToSuperview()
        }

        let descriptionView = UIView.vStack(
            alignment: .fill,
            spacing: 8.0,
            [titleLabel, detailsLabel]
        )

        addSubview(descriptionView)

        descriptionView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(iconImageView.snp.leading).offset(-8)
        }

        addSubview(closeButton)

        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.width.equalTo(56)
            make.height.equalTo(44)
        }
    }
}

extension PromotionBannerView {
    struct ViewModel {
        let background: UIImage
        let title: String
        let details: String
        let icon: UIImage?
    }

    func bind(viewModel: ViewModel) {
        backgroundView.image = viewModel.background
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.details
        iconImageView.image = viewModel.icon
    }
}
