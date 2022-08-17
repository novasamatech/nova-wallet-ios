import UIKit
import SoraUI

final class YourContributionsView: UIView {
    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorTransparentText()
        $0.font = .regularSubheadline
        $0.numberOfLines = 1
    }

    let counterLabel: BorderedLabelView = .create {
        $0.titleLabel.textAlignment = .center
        $0.contentInsets = Constants.counterLabelContentInsets
    }

    let amountLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite()
        $0.font = .boldLargeTitle
        $0.textAlignment = .center
    }

    let amountDetailsLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite64()
        $0.font = .regularBody
        $0.textAlignment = .center
    }

    let navigationImageView: UIImageView = .create {
        $0.image = R.image.iconSmallArrow()?.withRenderingMode(.alwaysTemplate)
        $0.contentMode = .center
        $0.tintColor = R.color.colorWhite48()
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
        let titleView = UIView()
        titleView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
        }
        titleView.addSubview(counterLabel)
        counterLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel.snp.trailing).offset(Constants.counterTitleSpace)
            $0.top.trailing.bottom.equalToSuperview()
        }
        let contentStackView = UIStackView(arrangedSubviews: [
            titleView,
            amountLabel,
            amountDetailsLabel
        ])
        contentStackView.spacing = Constants.verticalSpace
        contentStackView.axis = .vertical
        contentStackView.distribution = .fillProportionally
        contentStackView.alignment = .center

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.bottom.equalToSuperview().inset(Constants.topBottomInsets)
        }
        addSubview(navigationImageView)
        navigationImageView.snp.makeConstraints {
            $0.leading.greaterThanOrEqualTo(contentStackView.snp.trailing)
            $0.centerY.equalTo(titleView.snp.centerY)
            $0.trailing.equalToSuperview().inset(Constants.navigationImageViewRightOffset)
            $0.width.equalTo(Constants.navigationImageViewSize.width)
            $0.height.equalTo(Constants.navigationImageViewSize.height)
        }
    }
}

// MARK: - Bind

extension YourContributionsView {
    struct Model {
        let title: String
        let count: String
        let amount: String
        let amountDetails: String
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        counterLabel.titleLabel.text = model.count
        amountLabel.text = model.amount
        amountDetailsLabel.text = model.amountDetails
    }
}

// MARK: - Constants

extension YourContributionsView {
    private enum Constants {
        static let blurViewSideLength: CGFloat = 12
        static let counterLabelContentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 3, right: 8)
        static let counterTitleSpace: CGFloat = 8
        static let verticalSpace: CGFloat = 4
        static let topBottomInsets: CGFloat = 20
        static let navigationImageViewSize = CGSize(width: 24, height: 24)
        static let navigationImageViewRightOffset: CGFloat = 16
    }
}
