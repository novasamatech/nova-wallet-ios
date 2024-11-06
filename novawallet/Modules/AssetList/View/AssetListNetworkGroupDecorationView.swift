import UIKit
import SnapKit

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
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)

        guard let customAttributes = layoutAttributes as? AssetListCustomLayoutAttributes else {
            return
        }

        if customAttributes.isExpanded {
            updateForExpanded()
        } else {
            updateForCollapsed()
        }
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
            make.top.equalTo(backgroundView.snp.bottom)
            make.bottom.equalToSuperview()

            make.leading.equalToSuperview().inset(16)
            make.trailing.equalToSuperview().inset(16)
        }
    }

    private func setupStyle() {
        underneathView.contentView?.fillColor = R.color.colorHiddenNetworkBlockBackground()!

        backgroundView.sideLength = 12
        underneathView.sideLength = 12

        underneathView.cornerCut = [.bottomLeft, .bottomRight]
        backgroundView.cornerCut = .allCorners
    }

    private func updateForExpanded() {
        underneathView.contentView?.fillColor = R.color.colorBlockBackground()!

        backgroundView.cornerCut = [.topLeft, .topRight]

        underneathView.snp.updateConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
    }

    private func updateForCollapsed() {
        underneathView.contentView?.fillColor = R.color.colorHiddenNetworkBlockBackground()!

        backgroundView.cornerCut = .allCorners

        underneathView.snp.updateConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalToSuperview().inset(16)
        }
    }
}
