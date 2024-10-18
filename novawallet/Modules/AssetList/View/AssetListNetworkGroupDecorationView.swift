import UIKit

final class AssetListNetworkGroupDecorationView: UICollectionReusableView {
    let backgroundView = BlockBackgroundView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

final class AssetListTokenGroupDecorationView: UICollectionReusableView {
    let backgroundView = BlockBackgroundView()
    let underneathView = BlockBackgroundView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        underneathView.contentView?.fillColor = R.color.colorHiddenNetworkBlockBackground()!
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(underneathView)
        addSubview(backgroundView)

        bringSubviewToFront(backgroundView)

        backgroundView.snp.makeConstraints { make in
            make.height.equalTo(64)
            make.leading.trailing.top.equalToSuperview()
        }

        underneathView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }
}
