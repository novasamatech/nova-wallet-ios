import UIKit

final class DAppPhishingViewLayout: UIView {
    private enum Constants {
        static let iconSize = CGSize(width: 88, height: 88)
        static let iconInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        static var displayIconSize: CGSize {
            CGSize(
                width: iconSize.width - iconInsets.left - iconInsets.right,
                height: iconSize.height - iconInsets.top - iconInsets.bottom
            )
        }
    }

    let iconView: DAppIconView = {
        let view = DAppIconView()
        view.backgroundView.cornerRadius = 24.0
        let viewModel = StaticImageViewModel(image: R.image.iconWarningApp()!)
        view.bind(viewModel: viewModel, size: Constants.displayIconSize)
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .semiBoldTitle3
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.numberOfLines = 3
        label.textAlignment = .center
        return label
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.color0x1D1D20()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(4.0)
            make.size.equalTo(Constants.iconSize)
            make.centerX.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(20.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
