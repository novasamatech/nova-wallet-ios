import UIKit

final class ReferendumsPersonalActivityView: GenericTitleValueView<
    GenericPairValueView<
        IconDetailsView,
        GenericBorderedView<DotsSecureView<UILabel>>
    >,
    GenericPairValueView<HideSecureView<UILabel>, UIImageView>
> {
    var titleLabel: UILabel {
        titleView.fView.detailsLabel
    }

    var valueBorderedView: GenericBorderedView<DotsSecureView<UILabel>> {
        titleView.sView
    }

    var valueSecureView: DotsSecureView<UILabel> {
        valueBorderedView.contentView
    }

    var valueLabel: UILabel {
        valueSecureView.originalView
    }

    var detailsSecureView: HideSecureView<UILabel> {
        valueView.fView
    }

    var detailsLabel: UILabel {
        detailsSecureView.originalView
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

        valueBorderedView.backgroundView.fillColor = R.color.colorChipsBackground()!
        valueBorderedView.contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        valueBorderedView.backgroundView.cornerRadius = 7
        titleView.fView.iconWidth = 24
        titleView.fView.spacing = 12

        valueView.makeHorizontal()
        valueView.spacing = 4
        valueView.sView.snp.makeConstraints { make in
            make.size.equalTo(24)
        }

        valueView.sView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)

        valueBorderedView.snp.makeConstraints { make in
            make.height.equalTo(22)
        }
    }
}

extension ReferendumsPersonalActivityView {
    func bind(
        viewModel: SecuredViewModel<ReferendumsUnlocksViewModel>,
        locale: Locale
    ) {
        valueBorderedView.isHidden = false
        titleLabel.text = R.string.localizable.walletBalanceLocked(preferredLanguages: locale.rLanguages)
        valueLabel.text = viewModel.originalContent.totalLock
        detailsLabel.text = viewModel.originalContent.hasUnlock ?
            R.string.localizable.commonUnlock(preferredLanguages: locale.rLanguages) : ""
        titleView.fView.imageView.image = R.image.iconLockClosed()

        valueSecureView.bind(viewModel.privacyMode)
        detailsSecureView.bind(viewModel.privacyMode)

        setNeedsLayout()
    }
}

extension ReferendumsPersonalActivityView {
    func bind(
        viewModel: SecuredViewModel<ReferendumsDelegationViewModel>,
        locale: Locale
    ) {
        let strings = R.string.localizable.self
        switch viewModel.originalContent {
        case .addDelegation:
            titleLabel.text = strings.delegationsAddTitle(preferredLanguages: locale.rLanguages)
            valueBorderedView.isHidden = true
        case let .delegations(total):
            titleLabel.text = strings.governanceReferendumsYourDelegations(preferredLanguages: locale.rLanguages)
            valueBorderedView.isHidden = false
            valueLabel.text = total
        }

        valueSecureView.bind(viewModel.privacyMode)

        detailsLabel.text = nil
        titleView.fView.imageView.image = R.image.iconDelegate()

        setNeedsLayout()
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
