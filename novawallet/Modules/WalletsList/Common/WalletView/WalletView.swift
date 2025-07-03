import UIKit

final class WalletView: GenericTitleValueView<
    WalletIconView,
    GenericPairValueView<
        IconDetailsView,
        GenericPairValueView<UILabel, IconDetailsView>
    >
>, WalletViewProtocol {
    var viewModel: ViewModel?

    var iconImageView: UIImageView { titleView.iconViewImageView }
    var networkImageView: UIImageView { titleView.networkIconImageView }

    var titleLabel: UILabel { valueView.fView.detailsLabel }
    var indicatorImageView: UIImageView { valueView.fView.imageView }
    var subtitleLabel: UILabel { valueView.sView.fView }
    var subtitleDetailsImage: UIImageView { valueView.sView.sView.imageView }
    var subtitleDetailsLabel: UILabel { valueView.sView.sView.detailsLabel }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    func setupStyle() {
        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        spacing = 12
        alignment = .left
        indicatorImageView.snp.makeConstraints {
            $0.height.width.equalTo(8)
        }
        indicatorImageView.layer.cornerRadius = 4
        indicatorImageView.backgroundColor = R.color.colorIconAccent()!
        indicatorImageView.isHidden = true
        subtitleLabel.apply(style: .footnoteSecondary)
        valueView.sView.sView.iconWidth = 16
        subtitleDetailsLabel.numberOfLines = 1
        subtitleDetailsLabel.apply(style: .footnotePrimary)
        subtitleDetailsLabel.lineBreakMode = .byTruncatingMiddle
        valueView.fView.mode = .detailsIcon
        valueView.sView.makeHorizontal()
        valueView.sView.spacing = 4
        valueView.spacing = 4

        titleView.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueView.setContentCompressionResistancePriority(.low, for: .horizontal)
        subtitleLabel.setContentHuggingPriority(.required, for: .horizontal)
        subtitleDetailsLabel.setContentCompressionResistancePriority(.low, for: .horizontal)
        subtitleDetailsLabel.setContentHuggingPriority(.low, for: .horizontal)
    }
}

extension WalletView {
    struct ViewModel: Hashable {
        let wallet: WalletInfo
        let type: TypeInfo

        enum TypeInfo: Hashable {
            case regular(BalanceInfo)
            case proxy(DelegatedAccountInfo)
            case multisig(DelegatedAccountInfo)
            case noInfo
        }

        struct WalletInfo: Hashable {
            let icon: IdentifiableImageViewModelProtocol?
            let name: String

            static func == (lhs: WalletInfo, rhs: WalletInfo) -> Bool {
                lhs.icon?.identifier == rhs.icon?.identifier &&
                    lhs.name == rhs.name
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(icon?.identifier ?? "")
                hasher.combine(name)
            }
        }

        struct DelegatedAccountInfo: Hashable {
            let networkIcon: IdentifiableImageViewModelProtocol?
            let type: String
            let pairedAccountIcon: IdentifiableImageViewModelProtocol?
            let pairedAccountName: String?
            let isNew: Bool

            static func == (lhs: DelegatedAccountInfo, rhs: DelegatedAccountInfo) -> Bool {
                lhs.networkIcon?.identifier == rhs.networkIcon?.identifier &&
                    lhs.type == rhs.type &&
                    lhs.pairedAccountIcon?.identifier == rhs.pairedAccountIcon?.identifier &&
                    lhs.pairedAccountName == rhs.pairedAccountName &&
                    lhs.isNew == rhs.isNew
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(networkIcon?.identifier ?? "")
                hasher.combine(type)
                hasher.combine(pairedAccountIcon?.identifier ?? "")
                hasher.combine(pairedAccountName ?? "")
                hasher.combine(isNew)
            }
        }

        typealias BalanceInfo = String

        var delegatedAccountInfo: DelegatedAccountInfo? {
            switch type {
            case let .proxy(info), let .multisig(info):
                return info
            case .regular, .noInfo:
                return nil
            }
        }
    }

    func cancelIconsLoading(info: ViewModel.DelegatedAccountInfo?) {
        info?.networkIcon?.cancel(on: networkImageView)
        networkImageView.image = nil

        info?.pairedAccountIcon?.cancel(on: subtitleDetailsImage)
        subtitleDetailsImage.image = nil

        titleView.clear()
    }

    func bind(regular viewModel: ViewModel.BalanceInfo) {
        subtitleLabel.text = viewModel
        subtitleDetailsLabel.text = nil
        networkImageView.isHidden = true
        subtitleDetailsImage.isHidden = true
        indicatorImageView.isHidden = true
    }

    func bindNoInfo() {
        subtitleLabel.text = nil
        subtitleDetailsLabel.text = nil
        networkImageView.isHidden = true
        subtitleDetailsImage.isHidden = true
        indicatorImageView.isHidden = true
    }

    func bind(delegatedAccount viewModel: ViewModel.DelegatedAccountInfo) {
        viewModel.networkIcon?.loadImage(
            on: networkImageView,
            targetSize: WalletIconView.Constants.networkIconSize,
            animated: true
        )

        viewModel.pairedAccountIcon?.loadImage(
            on: subtitleDetailsImage,
            targetSize: .init(width: 16, height: 16),
            animated: true
        )

        subtitleLabel.text = viewModel.type
        subtitleDetailsLabel.text = viewModel.pairedAccountName
        networkImageView.isHidden = viewModel.networkIcon == nil
        subtitleDetailsImage.isHidden = viewModel.pairedAccountIcon == nil
        indicatorImageView.isHidden = !viewModel.isNew

        titleView.setNeedsLayout()
    }

    func setAppearance(for selectionAvailable: Bool) {
        if selectionAvailable {
            titleLabel.textColor = R.color.colorTextPrimary()
            subtitleDetailsLabel.textColor = R.color.colorTextPrimary()
        } else {
            titleLabel.textColor = R.color.colorTextSecondary()
            subtitleDetailsLabel.textColor = R.color.colorTextSecondary()
        }

        let alpha = selectionAvailable ? 1.0 : 0.5

        [
            networkImageView,
            iconImageView,
            subtitleDetailsImage
        ].forEach { $0.alpha = alpha }
    }
}
