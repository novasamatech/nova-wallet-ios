import UIKit

final class AssetListBannerCell: UICollectionViewCell {
    let bannerView = PromotionBannerView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(bannerView)

        bannerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }
    }

    func bind(viewModel: PromotionBannerView.ViewModel) {
        bannerView.bind(viewModel: viewModel)
    }
}
