import Foundation
import UIKit
import SoraUI

final class ProxyTableViewCell: PlainBaseTableViewCell<ProxyWalletView> {
    override func prepareForReuse() {
        super.prepareForReuse()

        contentDisplayView.cancelImagesLoading()
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }

    func bind(viewModel: ProxyWalletView.ViewModel) {
        contentDisplayView.bind(viewModel: viewModel)
    }
}

final class ProxyWalletView: GenericTitleValueView<ProxyIconView, GenericPairValueView<IconDetailsView, GenericPairValueView<UILabel, IconDetailsView>>> {
    private var viewModel: ViewModel?

    var iconImageView: UIImageView { titleView.iconViewImageView }
    var networkImageView: UIImageView { titleView.networkIconImageView }

    var titleLabel: UILabel { valueView.fView.detailsLabel }
    var indicatorImageView: UIImageView { valueView.fView.imageView }
    var typeLabel: UILabel { valueView.sView.fView }
    var proxyImage: UIImageView { valueView.sView.sView.imageView }
    var proxyName: UILabel { valueView.sView.sView.detailsLabel }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    func setupStyle() {
        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        spacing = 8
        alignment = .left
        indicatorImageView.snp.makeConstraints {
            $0.height.width.equalTo(8)
        }
        indicatorImageView.backgroundColor = R.color.colorIconAccent()!
        indicatorImageView.isHidden = true
        typeLabel.apply(style: .footnoteSecondary)
        valueView.sView.sView.iconWidth = 16
        proxyName.apply(style: .footnotePrimary)
        valueView.fView.mode = .detailsIcon
        valueView.sView.makeHorizontal()
        valueView.sView.spacing = 4
    }
}

extension ProxyWalletView {
    struct ViewModel: Hashable, Equatable {
        let icon: IdentifiableImageViewModelProtocol?
        let networkIcon: IdentifiableImageViewModelProtocol?
        let name: String
        let subtitle: String
        let subtitleDetailsIcon: IdentifiableImageViewModelProtocol?
        let subtitleDetails: String

        static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
            lhs.icon?.identifier == rhs.icon?.identifier &&
                lhs.networkIcon?.identifier == rhs.networkIcon?.identifier &&
                lhs.name == rhs.name &&
                lhs.subtitle == rhs.subtitle &&
                lhs.subtitleDetailsIcon?.identifier == rhs.subtitleDetailsIcon?.identifier &&
                lhs.subtitleDetails == rhs.subtitleDetails
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(icon?.identifier ?? "")
            hasher.combine(networkIcon?.identifier ?? "")
            hasher.combine(name)
            hasher.combine(subtitle)
            hasher.combine(subtitleDetailsIcon?.identifier ?? "")
            hasher.combine(subtitleDetails)
        }
    }

    func cancelImagesLoading() {
        viewModel?.icon?.cancel(on: iconImageView)
        iconImageView.image = nil

        viewModel?.networkIcon?.cancel(on: networkImageView)
        networkImageView.image = nil

        viewModel?.subtitleDetailsIcon?.cancel(on: proxyImage)
        proxyImage.image = nil
    }

    func bind(viewModel: ViewModel) {
        cancelImagesLoading()

        viewModel.icon?.loadImage(
            on: iconImageView,
            targetSize: ProxyIconView.Constants.iconSize,
            animated: true
        )

        viewModel.networkIcon?.loadImage(
            on: networkImageView,
            targetSize: ProxyIconView.Constants.networkIconSize,
            animated: true
        )

        viewModel.subtitleDetailsIcon?.loadImage(
            on: proxyImage,
            targetSize: .init(width: 16, height: 16),
            animated: true
        )

        titleLabel.text = viewModel.name
        typeLabel.text = viewModel.subtitle
        proxyName.text = viewModel.subtitleDetails

        self.viewModel = viewModel
    }
}
