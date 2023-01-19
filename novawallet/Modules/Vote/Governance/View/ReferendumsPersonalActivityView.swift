import UIKit

final class ReferendumsPersonalActivityView: GenericTitleValueView<
    GenericPairValueView<IconDetailsView, BorderedLabelView>, IconDetailsView
> {
    var titleLabel: UILabel {
        titleView.fView.detailsLabel
    }

    var valueLabel: UILabel {
        titleView.sView.titleLabel
    }

    var detailsLabel: UILabel {
        valueView.detailsLabel
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        titleView.setHorizontalAndSpacing(8.0)

        titleLabel.apply(style: .regularSubhedlinePrimary)

        valueLabel.apply(style: .footnoteSecondary)
        valueLabel.numberOfLines = 1

        detailsLabel.apply(style: .unlockStyle)
        detailsLabel.numberOfLines = 1

        titleView.sView.backgroundView.fillColor = R.color.colorChipsBackground()!
        titleView.sView.contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        titleView.sView.backgroundView.cornerRadius = 6
        titleView.fView.iconWidth = 24
        valueView.mode = .detailsIcon
        valueView.spacing = 4
        valueView.iconWidth = 24
        valueView.imageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
    }
}

extension ReferendumsPersonalActivityView {
    func bind(viewModel: ReferendumsUnlocksViewModel, locale: Locale) {
        titleView.sView.isHidden = false
        titleLabel.text = R.string.localizable.walletBalanceLocked(preferredLanguages: locale.rLanguages)
        valueLabel.text = viewModel.totalLock
        detailsLabel.text = viewModel.hasUnlock ?
            R.string.localizable.commonUnlock(preferredLanguages: locale.rLanguages) : ""
        titleView.fView.imageView.image = R.image.iconLockClosed()
    }
}

extension ReferendumsPersonalActivityView {
    func bind(viewModel: ReferendumsDelegationViewModel, locale: Locale) {
        let strings = R.string.localizable.self
        switch viewModel {
        case .addDelegation:
            titleLabel.text = strings.governanceReferendumsAddDelegation(preferredLanguages: locale.rLanguages)
            titleView.sView.isHidden = true
        case let .delegations(total):
            titleLabel.text = strings.governanceReferendumsYourDelegations(preferredLanguages: locale.rLanguages)
            titleView.sView.isHidden = false
            valueLabel.text = total
        }

        detailsLabel.text = nil
        titleView.fView.imageView.image = R.image.iconDelegate()
    }
}

private extension UILabel.Style {
    static var unlockStyle: UILabel.Style {
        .init(textColor: R.color.colorTextPositive()!, font: .caption1)
    }
}

typealias ReferendumsUnlocksTableViewCell = BlurredTableViewCell<ReferendumsPersonalActivityView>
typealias ReferendumsDelegationsTableViewCell = BlurredTableViewCell<ReferendumsPersonalActivityView>

extension BlurredTableViewCell where TContentView == ReferendumsPersonalActivityView {
    func applyStyle(cornerCut: UIRectCorner = .allCorners) {
        shouldApplyHighlighting = true
        contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        backgroundBlurView.cornerCut = cornerCut
    }
}
