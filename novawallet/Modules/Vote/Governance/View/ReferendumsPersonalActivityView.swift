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

        valueLabel.apply(style: .semiboldChip)
        valueLabel.numberOfLines = 1

        detailsLabel.apply(style: .unlockStyle)
        detailsLabel.numberOfLines = 1

        titleView.sView.backgroundView.fillColor = R.color.colorChipsBackground()!
        titleView.sView.contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        titleView.sView.backgroundView.cornerRadius = 7
        titleView.fView.iconWidth = 24
        titleView.fView.spacing = 12
        valueView.mode = .detailsIcon
        valueView.spacing = 4
        valueView.iconWidth = 24
        valueView.imageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
    }
}

extension ReferendumsPersonalActivityView {
    func bind(viewModel: ReferendumsUnlocksViewModel, locale: Locale) {
        titleView.sView.isHidden = false
        titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.walletBalanceLocked()
        valueLabel.text = viewModel.totalLock
        detailsLabel.text = viewModel.hasUnlock ?
            R.string(preferredLanguages: locale.rLanguages).localizable.commonUnlock() : ""
        titleView.fView.imageView.image = R.image.iconLockClosed()
    }
}

extension ReferendumsPersonalActivityView {
    func bind(viewModel: ReferendumsDelegationViewModel, locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable.self
        switch viewModel {
        case .addDelegation:
            titleLabel.text = strings.delegationsAddTitle()
            titleView.sView.isHidden = true
        case let .delegations(total):
            titleLabel.text = strings.governanceReferendumsYourDelegations()
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
    func applyStyle(for position: TableViewCellPosition) {
        shouldApplyHighlighting = true
        contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        switch position {
        case .single:
            innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            backgroundBlurView.cornerCut = .allCorners
        case .top:
            innerInsets = UIEdgeInsets(top: 6, left: 16, bottom: 0, right: 16)
            backgroundBlurView.cornerCut = [.topLeft, .topRight]
        case .middle:
            innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            backgroundBlurView.cornerCut = []
        case .bottom:
            innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 6, right: 16)
            backgroundBlurView.cornerCut = [.bottomLeft, .bottomRight]
        }
    }
}
