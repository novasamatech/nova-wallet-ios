import UIKit
import SoraUI

final class StakingStatusView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        return view
    }()

    let glowingView = GlowingView()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldCaps2
        return label
    }()

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
            detailsLabel.text = R.string.localizable.stakingNominatorStatusActive(
                preferredLanguages: locale.rLanguages
            ).uppercased()
        case .inactive:
            glowingView.outerFillColor = R.color.colorTextNegative()!.withAlphaComponent(0.4)
            glowingView.innerFillColor = R.color.colorTextNegative()!
            detailsLabel.textColor = R.color.colorTextNegative()!
            detailsLabel.text = R.string.localizable.stakingNominatorStatusInactive(
                preferredLanguages: locale.rLanguages
            ).uppercased()
        case .waiting:
            glowingView.outerFillColor = R.color.colorTextSecondary()!.withAlphaComponent(0.4)
            glowingView.innerFillColor = R.color.colorTextSecondary()!
            detailsLabel.textColor = R.color.colorTextPrimary()!
            detailsLabel.text = R.string.localizable.stakingNominatorStatusWaiting(
                preferredLanguages: locale.rLanguages
            ).uppercased()
        }
    }
}
