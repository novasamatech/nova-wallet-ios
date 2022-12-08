import UIKit

final class MultichainTokenView: UIView {
    enum Constants {
        static let preferredHeight: CGFloat = 40
        static let iconBackgroundSize = CGSize(width: 40, height: 40)
        static let iconInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        static var iconSize: CGSize {
            CGSize(
                width: iconBackgroundSize.width - iconInsets.left - iconInsets.right,
                height: iconBackgroundSize.height - iconInsets.top - iconInsets.bottom
            )
        }
    }

    let iconView: AssetIconView = .create {
        $0.backgroundView.apply(style: .assetContainer)
        $0.backgroundView.cornerRadius = Constants.iconBackgroundSize.height / 2.0
    }

    let detailsView: MultiValueView = .create { view in
        view.valueTop.textAlignment = .left
        view.valueTop.textColor = R.color.colorTextPrimary()
        view.valueTop.font = .semiBoldBody

        view.valueBottom.textAlignment = .left
        view.valueBottom.textColor = R.color.colorTextSecondary()
        view.valueBottom.font = .regularFootnote

        view.spacing = 0
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Constants.preferredHeight)
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

    func bind(viewModel: TokenManageViewModel) {
        let style: Style = viewModel.isOn ? MultichainTokenView.enabledStyle : MultichainTokenView.disabledStyle

        let imageSettings = ImageViewModelSettings(
            targetSize: Constants.iconSize,
            cornerRadius: nil,
            tintColor: style.iconColor
        )

        iconView.bind(viewModel: viewModel.imageViewModel, settings: imageSettings)

        detailsView.valueTop.text = viewModel.symbol
        detailsView.valueTop.textColor = style.titleColor

        detailsView.valueBottom.text = viewModel.subtitle
        detailsView.valueBottom.textColor = style.subtitleColor
    }

    private func setupLayout() {
        addSubview(iconView)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconBackgroundSize)
        }

        addSubview(detailsView)

        detailsView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.trailing.equalToSuperview()
        }
    }
}

extension MultichainTokenView {
    struct Style {
        let titleColor: UIColor
        let subtitleColor: UIColor
        let iconColor: UIColor
    }

    static var enabledStyle: Style {
        .init(
            titleColor: R.color.colorTextPrimary()!,
            subtitleColor: R.color.colorTextSecondary()!,
            iconColor: R.color.colorIconPrimary()!
        )
    }

    static var disabledStyle: Style {
        .init(
            titleColor: R.color.colorTextSecondary()!,
            subtitleColor: R.color.colorTextSecondary()!,
            iconColor: R.color.colorIconSecondary()!
        )
    }
}
