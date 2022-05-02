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
