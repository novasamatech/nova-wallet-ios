import UIKit

final class DAppAuthConfirmViewLayout: UIView {
    static let iconSize = CGSize(width: 56.0, height: 56.0)
    static let listImageSize = CGSize(width: 24.0, height: 24.0)

    let sourceAppIconView = DAppIconView()

    let destinationAppIconView = DAppIconView()

    let accessImageView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconDappAccess()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .semiBoldTitle3
        label.textAlignment = .center
        label.numberOfLines = 3
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .regularFootnote
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }()

    let walletView: RowView<GenericTitleValueView<UILabel, IconDetailsView>> = {
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .regularFootnote

        let valueView = IconDetailsView()
        valueView.iconWidth = 24.0
        valueView.mode = .iconDetails
        valueView.spacing = 8.0
        valueView.detailsLabel.textColor = R.color.colorWhite()
        valueView.detailsLabel.font = .regularFootnote
        valueView.detailsLabel.numberOfLines = 1

        let titleView = GenericTitleValueView(titleView: titleLabel, valueView: valueView)
        let rowView = RowView(contentView: titleView, preferredHeight: 48.0)
        rowView.borderView.strokeColor = R.color.colorWhite16()!
        rowView.borderView.strokeWidth = 0.5
        rowView.isUserInteractionEnabled = false
        rowView.contentInsets = .zero
        return rowView
    }()

    let dappView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.textColor = R.color.colorTransparentText()
        view.titleLabel.font = .regularFootnote
        view.valueLabel.textColor = R.color.colorWhite()
        view.valueLabel.font = .regularFootnote
        view.borderView.borderType = .none
        view.valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return view
    }()

    let denyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        return button
    }()

    let allowButton: TriangularedButton = {
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

    // swiftlint:disable:next function_body_length
    private func setupLayout() {
        addSubview(accessImageView)
        accessImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(36.0)
            make.centerX.equalToSuperview()
        }

        addSubview(sourceAppIconView)
        sourceAppIconView.snp.makeConstraints { make in
            make.centerY.equalTo(accessImageView.snp.centerY)
            make.trailing.equalTo(accessImageView.snp.leading).offset(-8.0)
            make.size.equalTo(88.0)
        }

        addSubview(destinationAppIconView)
        destinationAppIconView.snp.makeConstraints { make in
            make.centerY.equalTo(accessImageView.snp.centerY)
            make.leading.equalTo(accessImageView.snp.trailing).offset(8.0)
            make.size.equalTo(88.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(112.0)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
        }

        addSubview(walletView)
        walletView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(24.0)
            make.height.equalTo(48.0)
        }

        addSubview(dappView)
        dappView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(walletView.snp.bottom)
            make.height.equalTo(48.0)
        }

        addSubview(denyButton)
        denyButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(self.snp.centerX).offset(-8.0)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16.0)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(allowButton)
        allowButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.leading.equalTo(self.snp.centerX).offset(8.0)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16.0)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
