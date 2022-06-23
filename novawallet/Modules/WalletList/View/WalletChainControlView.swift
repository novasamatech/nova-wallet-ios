import UIKit
import SoraUI

final class WalletChainControlView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorWhite16()!
        view.highlightedFillColor = R.color.colorWhite16()!
        view.cornerRadius = 7.0
        return view
    }()

    let iconView: GradientIconView = {
        let view = GradientIconView()
        view.backgroundView.cornerRadius = 8.0
        return view
    }()

    let actionControl: ActionTitleControl = {
        let view = ActionTitleControl()
        let color = R.color.colorNovaBlue()!
        view.imageView.image = R.image.iconLinkChevron()?.tinted(with: color)
        view.identityIconAngle = CGFloat.pi / 2.0
        view.activationIconAngle = -CGFloat.pi / 2.0
        view.titleLabel.textColor = color
        view.titleLabel.font = .semiBoldCaps1
        view.horizontalSpacing = 2.0
        return view
    }()

    let iconSize = CGSize(width: 24.0, height: 24.0)

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: NetworkViewModel) {
        actionControl.titleLabel.text = viewModel.name.uppercased()
        iconView.bind(gradient: viewModel.gradient)

        iconView.bind(iconViewModel: viewModel.icon, size: iconSize)

        actionControl.invalidateLayout()
        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(iconView)
        addSubview(actionControl)

        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.size.equalTo(24.0)
        }

        actionControl.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8.0)
            make.trailing.equalToSuperview().inset(8.0)
            make.top.bottom.equalToSuperview()
        }

        backgroundView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(1.0)
            make.trailing.equalToSuperview()
        }
    }
}
