import UIKit
import SoraUI

final class WalletChainView: UIView {
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

    let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite80()
        label.font = .semiBoldCaps1
        return label
    }()

    let iconSize = CGSize(width: 24.0, height: 24.0)

    convenience init() {
        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 48.0, height: 24.0))
        self.init(frame: defaultFrame)
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

    func bind(viewModel: NetworkViewModel) {
        nameLabel.text = viewModel.name.uppercased()
        iconView.bind(gradient: viewModel.gradient)

        iconView.bind(iconViewModel: viewModel.icon, size: iconSize)

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        addSubview(iconView)
        addSubview(nameLabel)

        iconView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.size.equalTo(iconSize)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8.0)
            make.trailing.equalToSuperview().inset(8.0)
            make.centerY.equalTo(iconView)
        }

        backgroundView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview().inset(1.0)
            make.trailing.equalToSuperview()
        }
    }
}
