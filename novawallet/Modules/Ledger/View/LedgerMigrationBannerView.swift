import UIKit
import UIKit_iOS

class LedgerMigrationBannerView: GenericBorderedView<
    IconDetailsGenericView<GenericPairValueView<MultiValueView, RoundedButton>>
> {
    var iconView: UIImageView { contentView.imageView }

    var titleLabel: UILabel { contentView.detailsView.fView.valueTop }

    var detailsLabel: UILabel { contentView.detailsView.fView.valueBottom }

    var actionButton: RoundedButton { contentView.detailsView.sView }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()

        actionButton.addTarget(
            self,
            action: #selector(performAction),
            for: .touchUpInside
        )
    }

    private var onAction: (() -> Void)?

    func configure() {
        backgroundView.cornerRadius = 12
        contentView.stackView.alignment = .top
        contentView.spacing = 12

        contentView.detailsView.fView.spacing = 8

        contentView.detailsView.makeVertical()
        contentView.detailsView.spacing = 0
        contentView.detailsView.stackView.alignment = .leading

        actionButton.snp.makeConstraints { make in
            make.height.equalTo(32)
        }

        contentInsets = UIEdgeInsets(top: 10, left: 12, bottom: 0, right: 12)

        titleLabel.apply(style: .caption1Primary)
        titleLabel.textAlignment = .left

        detailsLabel.apply(style: .caption1Secondary)
        detailsLabel.textAlignment = .left
        detailsLabel.numberOfLines = 0

        actionButton.contentInsets = .zero
        actionButton.imageWithTitleView?.layoutType = .horizontalLabelFirst
        actionButton.applyIconStyle()
        actionButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 0
        actionButton.imageWithTitleView?.iconImage = R.image.iconLinkChevron()?.tinted(
            with: R.color.colorIconAccent()!
        )
        actionButton.imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()
        actionButton.imageWithTitleView?.titleFont = .caption1

        contentView.iconWidth = 16
    }

    func bind(viewModel: LedgerMigrationBannerView.ViewModel) {
        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.subtitle
        actionButton.imageWithTitleView?.title = viewModel.actionTitle

        onAction = viewModel.action

        setNeedsLayout()
    }

    func apply(style: Style) {
        iconView.image = style.icon
        backgroundView.fillColor = style.backgroundColor
    }

    @objc func performAction() {
        onAction?()
    }
}

extension LedgerMigrationBannerView {
    struct Style {
        let backgroundColor: UIColor
        let icon: UIImage
    }

    struct ViewModel {
        let title: String
        let subtitle: String
        let actionTitle: String
        let action: () -> Void
    }
}

extension LedgerMigrationBannerView.Style {
    static var warning: Self {
        .init(
            backgroundColor: R.color.colorCriticalChipBackground()!,
            icon: R.image.iconWarning()!
        )
    }

    static var info: Self {
        .init(
            backgroundColor: R.color.colorIndividualChipBackground()!,
            icon: R.image.iconInfoAccent()!
        )
    }
}

extension LedgerMigrationBannerView.ViewModel {
    static func createLedgerMigrationDownload(
        for locale: Locale?,
        action: @escaping () -> Void
    ) -> Self {
        .init(
            title: R.string.localizable.legacyLedgerNotificationTitle(preferredLanguages: locale?.rLanguages),
            subtitle: R.string.localizable.legacyLedgerNotificationMessage(preferredLanguages: locale?.rLanguages),
            actionTitle: R.string.localizable.commonFindMore(preferredLanguages: locale?.rLanguages),
            action: action
        )
    }

    static func createLedgerMigrationWillBeUnavailable(
        for locale: Locale?,
        action: @escaping () -> Void
    ) -> Self {
        .init(
            title: R.string.localizable.legacyLedgerNotificationTitle(preferredLanguages: locale?.rLanguages),
            subtitle: R.string.localizable.legacyLedgerMigrationMessage(preferredLanguages: locale?.rLanguages),
            actionTitle: R.string.localizable.commonFindMore(preferredLanguages: locale?.rLanguages),
            action: action
        )
    }
}
