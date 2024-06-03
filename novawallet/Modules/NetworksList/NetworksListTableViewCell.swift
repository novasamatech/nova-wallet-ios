import UIKit

final class NetworksListTableViewCell: PlainBaseTableViewCell<ChainAccountView> {
    var networkIconView: UIImageView { contentDisplayView.networkIconView }
    var networkLabel: UILabel { contentDisplayView.networkLabel }
    var actionIconView: UIImageView { contentDisplayView.actionIconView }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear

        actionIconView.contentMode = .scaleAspectFit
        actionIconView.image = R.image.iconSmallArrow()?.tinted(
            with: R.color.colorTextSecondary()!
        )
    }

    func bind(with viewModel: NetworksListViewLayout.NetworkWithConnectionModel) {
        viewModel.networkModel.network.icon?.loadImage(
            on: networkIconView,
            targetSize: Constants.iconSize,
            animated: true
        )

        networkLabel.text = viewModel.networkModel.network.name
    }
}

extension NetworksListTableViewCell {
    enum Constants {
        static let iconSize: CGSize = .init(width: 36, height: 36)
    }
}
