import UIKit_iOS
import UIKit

final class AssetListTokenGroupAssetCell: AssetListAssetCell {
    private let networkIconSize: CGFloat = 12

    let networkIconView: UIImageView = {
        let view = UIImageView()
        return view
    }()

    let networkLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        assetLabel.apply(style: .regularSubhedlinePrimary)
    }

    override func createDetailsView() -> UIView {
        let containerView = UIView()

        networkIconView.snp.makeConstraints { make in
            make.size.equalTo(networkIconSize)
        }

        containerView.addSubview(networkIconView)
        networkIconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        containerView.addSubview(networkLabel)
        networkLabel.snp.makeConstraints { make in
            make.leading.equalTo(networkIconView.snp.trailing).offset(4.0)
            make.bottom.top.trailing.equalToSuperview()
        }

        return containerView
    }

    func bind(viewModel: AssetListTokenGroupAssetViewModel) {
        bind(
            viewModel: viewModel,
            balanceKeyPath: \.balance,
            imageKeyPath: \.chainAsset.assetViewModel.imageViewModel,
            nameKeyPath: \.chainAsset.assetViewModel.symbol
        )

        applyNetwork(viewModel.chainAsset.networkViewModel)
    }

    private func applyNetwork(_ networkViewModel: NetworkViewModel) {
        networkLabel.text = networkViewModel.name

        networkViewModel.icon?.loadImage(
            on: networkIconView,
            settings: .init(
                targetSize: CGSize(
                    width: networkIconSize,
                    height: networkIconSize
                )
            ),
            animated: true
        )
    }
}
