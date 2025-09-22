import UIKit
import UIKit_iOS
import SnapKit

final class SwipeGovBannerContentView: GenericPairValueView<
    GenericPairValueView<
        UIImageView,
        GenericPairValueView<
            GenericPairValueView<
                UILabel,
                GenericBorderedView<DotsSecureView<UILabel>>
            >,
            UILabel
        >
    >,
    UIImageView
> {
    var iconView: UIImageView {
        fView.fView
    }

    var titleValueView: GenericPairValueView<
        GenericPairValueView<
            UILabel,
            GenericBorderedView<DotsSecureView<UILabel>>
        >,
        UILabel
    > {
        fView.sView
    }

    var counterView: GenericBorderedView<DotsSecureView<UILabel>> {
        titleValueView.fView.sView
    }

    var counterSecureView: DotsSecureView<UILabel> {
        counterView.contentView
    }

    var counterLabel: UILabel {
        counterSecureView.originalView
    }

    var titleLabel: UILabel {
        titleValueView.fView.fView
    }

    var valueLabel: UILabel {
        titleValueView.sView
    }

    var accessoryView: UIImageView {
        sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()

        backgroundColor = .clear
    }
}

// MARK: - Private

private extension SwipeGovBannerContentView {
    func configure() {
        setHorizontalAndSpacing(Constants.mainHorizontalSpacing)
        fView.setHorizontalAndSpacing(Constants.mainHorizontalSpacing)
        titleValueView.setVerticalAndSpacing(Constants.titleValueVerticalSpacing)
        titleValueView.stackView.alignment = .leading
        titleValueView.fView.setHorizontalAndSpacing(Constants.titleCounterHorizontalSpacing)
        titleValueView.fView.stackView.distribution = .equalCentering

        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.numberOfLines = 1

        valueLabel.apply(style: .caption1Secondary)
        valueLabel.numberOfLines = 0

        counterView.backgroundView.fillColor = R.color.colorChipsBackground()!
        counterLabel.apply(style: .semiboldChip)

        counterView.snp.makeConstraints { make in
            make.height.equalTo(Constants.counterViewHeight)
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.iconSize)
        }
        accessoryView.snp.makeConstraints { make in
            make.width.height.equalTo(Constants.accessorySize)
        }

        accessoryView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        accessoryView.contentMode = .scaleAspectFit

        iconView.image = R.image.iconSwipeGov()
        iconView.contentMode = .scaleAspectFit
    }
}

// MARK: - Internal

extension SwipeGovBannerContentView {
    func bind(with viewModel: SwipeGovBannerViewModel) {
        titleLabel.text = viewModel.title
        valueLabel.text = viewModel.description

        if let counterText = viewModel.referendumCounterText.originalContent {
            counterLabel.text = counterText
            counterLabel.isHidden = false
        } else {
            counterLabel.isHidden = true
        }

        counterSecureView.bind(viewModel.referendumCounterText.privacyMode)
    }
}

// MARK: - Constants

private extension SwipeGovBannerContentView {
    enum Constants {
        static let mainHorizontalSpacing: CGFloat = 12.0
        static let titleValueVerticalSpacing: CGFloat = 9.0
        static let titleCounterHorizontalSpacing: CGFloat = 8.0
        static let counterViewHeight: CGFloat = 22
        static let iconSize: CGFloat = 72
        static let accessorySize: CGFloat = 24
    }
}
