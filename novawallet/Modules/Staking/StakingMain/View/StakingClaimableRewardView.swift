import UIKit

final class StakingClaimableRewardView: UIView {
    let backgroundView: OverlayBlurBackgroundView = .create { view in
        view.sideLength = 12
        view.borderType = .none
        view.overlayView.fillColor = R.color.colorBlockBackground()!
        view.overlayView.strokeColor = R.color.colorCardActionsBorder()!
        view.overlayView.strokeWidth = 1
        view.blurView?.alpha = 0.5
    }

    let contentView: GenericTitleValueView<MultiValueView, TriangularedButton> = .create { view in
        view.titleView.valueTop.apply(style: .regularSubhedlinePrimary)
        view.titleView.valueTop.textAlignment = .left
        view.titleView.valueBottom.apply(style: .footnoteSecondary)
        view.titleView.valueBottom.textAlignment = .left
        view.titleView.spacing = 0.0

        view.valueView.applyDefaultStyle()
    }

    var rewardView: MultiValueView {
        contentView.titleView
    }

    var actionButton: TriangularedButton {
        contentView.valueView
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 70)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

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

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
}
