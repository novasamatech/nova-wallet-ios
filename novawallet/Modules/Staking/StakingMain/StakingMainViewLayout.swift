import UIKit
import SoraFoundation

final class StakingMainViewLayout: UIView {
    let backgroundView = MultigradientView.background

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        view.stackView.distribution = .fill
        view.stackView.spacing = 0.0
        return view
    }()

    let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .boldLargeTitle
        label.textColor = R.color.colorWhite()
        return label
    }()

    let walletSwitch = WalletSwitchControl()

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

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalTo(safeAreaLayoutGuide)
        }

        containerView.stackView.addArrangedSubview(headerView)

        headerView.addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
            make.size.equalTo(UIConstants.walletSwitchSize)
        }

        headerView.addSubview(headerLabel)
        headerLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(walletSwitch.snp.centerY)
            make.trailing.equalTo(walletSwitch.snp.leading).offset(-8.0)
        }

        containerView.stackView.setCustomSpacing(16.0, after: headerView)
    }
}
