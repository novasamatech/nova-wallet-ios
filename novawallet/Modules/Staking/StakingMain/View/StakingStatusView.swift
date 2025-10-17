import UIKit
import UIKit_iOS

class StakingStatusView: UIView {
    let backgroundView: RoundedView = .create { view in
        view.applyFilledBackgroundStyle()
    }

    let glowingView = GlowingView()

    let detailsLabel: UILabel = .create { label in
        label.font = .semiBoldCaps2
    }

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

        addSubview(glowingView)
        glowingView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(4.0)
        }

        addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.equalTo(glowingView.snp.trailing).offset(5.0)
            make.centerY.equalTo(glowingView)
            make.trailing.equalToSuperview().inset(8.0)
        }
    }
}

extension StakingStatusView {
    func bind(status: StakingDashboardEnabledViewModel.Status, locale: Locale) {
        switch status {
        case .active:
            glowingView.outerFillColor = R.color.colorTextPositive()!.withAlphaComponent(0.4)
            glowingView.innerFillColor = R.color.colorTextPositive()!
            detailsLabel.textColor = R.color.colorTextPositive()!
            detailsLabel.text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingNominatorStatusActive().uppercased()
        case .inactive:
            glowingView.outerFillColor = R.color.colorTextNegative()!.withAlphaComponent(0.4)
            glowingView.innerFillColor = R.color.colorTextNegative()!
            detailsLabel.textColor = R.color.colorTextNegative()!
            detailsLabel.text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingNominatorStatusInactive().uppercased()
        case .waiting:
            glowingView.outerFillColor = R.color.colorTextSecondary()!.withAlphaComponent(0.4)
            glowingView.innerFillColor = R.color.colorTextSecondary()!
            detailsLabel.textColor = R.color.colorTextPrimary()!
            detailsLabel.text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonWaiting().uppercased()
        }
    }
}

final class LoadableStakingStatusView: StakingStatusView, SkeletonableView {
    var skeletonView: SkrullableView?

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        []
    }

    var skeletonSpaceSize: CGSize { backgroundView.frame.size }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        [
            SingleSkeleton.createRow(
                on: backgroundView,
                containerView: backgroundView,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0, y: 0),
                size: spaceSize
            )
        ]
    }

    func updateLoadingAnimationIfActive() {
        if skeletonView != nil {
            updateLoadingState()

            skeletonView?.restartSkrulling()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if skeletonView != nil {
            updateLoadingState()
        }
    }
}
