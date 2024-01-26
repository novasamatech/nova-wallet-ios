import UIKit

final class WalletView: GenericTitleValueView<
    WalletIconView,
    GenericPairValueView<IconDetailsView, GenericPairValueView<UILabel, IconDetailsView>>
> {
    private var viewModel: ViewModel?

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
            case proxy(ProxyInfo)
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

        struct ProxyInfo: Hashable {
            let networkIcon: IdentifiableImageViewModelProtocol?
            let proxyType: String
            let proxyIcon: IdentifiableImageViewModelProtocol?
            let proxyName: String?
            let isNew: Bool

            static func == (lhs: ProxyInfo, rhs: ProxyInfo) -> Bool {
                lhs.networkIcon?.identifier == rhs.networkIcon?.identifier &&
                    lhs.proxyType == rhs.proxyType &&
                    lhs.proxyIcon?.identifier == rhs.proxyIcon?.identifier &&
                    lhs.proxyName == rhs.proxyName &&
                    lhs.isNew == rhs.isNew
            }

            func hash(into hasher: inout Hasher) {
                hasher.combine(networkIcon?.identifier ?? "")
                hasher.combine(proxyType)
                hasher.combine(proxyIcon?.identifier ?? "")
                hasher.combine(proxyName ?? "")
                hasher.combine(isNew)
            }
        }

        typealias BalanceInfo = String

        var proxyInfo: ProxyInfo? {
            switch type {
            case let .proxy(info):
                return info
            case .regular:
                return nil
            }
        }
    }

    func cancelImagesLoading() {
        cancelIconLoading(info: viewModel?.wallet)
        cancelProxyIconsLoading(info: viewModel?.proxyInfo)
    }

    private func cancelIconLoading(info: ViewModel.WalletInfo?) {
        info?.icon?.cancel(on: iconImageView)
        iconImageView.image = nil
    }

    private func cancelProxyIconsLoading(info: ViewModel.ProxyInfo?) {
        info?.networkIcon?.cancel(on: networkImageView)
        networkImageView.image = nil

        info?.proxyIcon?.cancel(on: subtitleDetailsImage)
        subtitleDetailsImage.image = nil

        titleView.clear()
    }

    func bind(viewModel: ViewModel) {
        bind(wallet: viewModel.wallet)

        switch viewModel.type {
        case let .regular(balanceViewModel):
            bind(regular: balanceViewModel)
        case let .proxy(proxyViewModel):
            bind(proxy: proxyViewModel)
        }

        self.viewModel = viewModel
    }

    private func bind(wallet viewModel: ViewModel.WalletInfo) {
        cancelImagesLoading()

        viewModel.icon?.loadImage(
            on: iconImageView,
            targetSize: WalletIconView.Constants.iconSize,
            animated: true
        )
        titleLabel.text = viewModel.name
    }

    private func bind(regular viewModel: ViewModel.BalanceInfo) {
        subtitleLabel.text = viewModel
        subtitleDetailsLabel.text = nil
        networkImageView.isHidden = true
        subtitleDetailsImage.isHidden = true
        indicatorImageView.isHidden = true
    }

    private func bind(proxy viewModel: ViewModel.ProxyInfo) {
        viewModel.networkIcon?.loadImage(
            on: networkImageView,
            targetSize: WalletIconView.Constants.networkIconSize,
            animated: true
        )

        viewModel.proxyIcon?.loadImage(
            on: subtitleDetailsImage,
            targetSize: .init(width: 16, height: 16),
            animated: true
        )

        subtitleLabel.text = viewModel.proxyType
        subtitleDetailsLabel.text = viewModel.proxyName
        networkImageView.isHidden = viewModel.networkIcon == nil
        subtitleDetailsImage.isHidden = viewModel.proxyIcon == nil
        indicatorImageView.isHidden = !viewModel.isNew

        titleView.setNeedsLayout()
    }
}
