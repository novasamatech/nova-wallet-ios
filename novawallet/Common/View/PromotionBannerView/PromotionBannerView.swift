import UIKit
import UIKit_iOS

protocol PromotionBannerViewDelegate: AnyObject {
    func promotionBannerDidRequestClose(view: PromotionBannerView)
}

final class PromotionBannerView: UIView {
    let backgroundView = UIImageView()

    let titleLabel: UILabel = .create { label in
        label.apply(style: Constants.titleStyle)
        label.numberOfLines = 0
    }

    let detailsLabel: UILabel = .create { label in
        label.apply(style: Constants.detailsStyle)
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
            make.trailing.equalToSuperview().inset(Constants.contentInset.right)
            make.centerY.equalToSuperview()
        }

        let descriptionView = UIView.vStack(
            spacing: Constants.descriptionVerticalSpacing,
            [titleLabel, detailsLabel]
        )

        addSubview(descriptionView)

        descriptionView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.contentInset.left)
            make.top.equalToSuperview().inset(Constants.contentInset.top)
            make.trailing.lessThanOrEqualTo(iconImageView.snp.leading).offset(-Constants.descriptionHorizontalSpacing)
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

extension PromotionBannerView {
    enum Constants {
        static let descriptionVerticalSpacing: CGFloat = 8
        static let descriptionHorizontalSpacing: CGFloat = 8
        static let contentInset: UIEdgeInsets = .init(top: 12, left: 16, bottom: 16, right: 24)
        static let titleStyle = UILabel.Style.semiboldSubhedlinePrimary
        static let detailsStyle = UILabel.Style.footnotePrimary
    }

    static func estimateHeight(for viewModel: ViewModel, width: CGFloat) -> CGFloat {
        let availableWidth: CGFloat

        let contentWidth = width - Constants.contentInset.left - Constants.contentInset.right

        if let icon = viewModel.icon {
            availableWidth = contentWidth - Constants.descriptionHorizontalSpacing - icon.size.width
        } else {
            availableWidth = contentWidth
        }

        let titleSize = viewModel.title.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: Constants.titleStyle.font],
            context: nil
        )

        let descriptionSize = viewModel.details.boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: Constants.detailsStyle.font],
            context: nil
        )

        let descriptionHeight = titleSize.height + descriptionSize.height + Constants.descriptionVerticalSpacing

        let contentHeight = max(descriptionHeight, viewModel.icon?.size.height ?? 0)

        return Constants.contentInset.top + contentHeight + Constants.contentInset.bottom
    }
}
