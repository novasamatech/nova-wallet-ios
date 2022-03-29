import UIKit
import SoraUI

final class DAppOperationConfirmViewLayout: UIView, AdaptiveDesignable {
    static let titleImageSize = CGSize(width: 56, height: 56)
    static let listImageSize = CGSize(width: 24, height: 24)

    let iconView: DAppIconView = {
        let view = DAppIconView()
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .semiBoldTitle3
        label.textAlignment = .center
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .regularFootnote
        label.numberOfLines = 3
        label.textAlignment = .center
        return label
    }()

    let walletView = createIconDetailsRowView()

    let accountAddressView = createIconDetailsRowView()

    let networkView = createIconDetailsRowView()

    let networkFeeView: NetworkFeeView = {
        let view = NetworkFeeView()
        view.titleLabel.textColor = R.color.colorTransparentText()
        view.titleLabel.font = .regularFootnote
        view.tokenLabel.textColor = R.color.colorWhite()
        view.tokenLabel.font = .regularFootnote
        view.borderView.strokeWidth = 0.5
        view.borderView.strokeColor = R.color.colorWhite16()!
        return view
    }()

    let transactionDetailsControl: RowView<GenericTitleValueView<UILabel, UIImageView>> = {
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.colorTransparentText()
        titleLabel.font = .regularFootnote

        let arrowImageView = UIImageView()
        arrowImageView.image = R.image.iconSmallArrow()?.withRenderingMode(.alwaysTemplate)
        arrowImageView.tintColor = R.color.colorWhite()

        let titleView = GenericTitleValueView(titleView: titleLabel, valueView: arrowImageView)

        let rowView = RowView(contentView: titleView, preferredHeight: 48.0)
        rowView.borderView.strokeWidth = 0.0
        rowView.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        return rowView
    }()

    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        return view
    }()

    let rejectButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        return button
    }()

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.color0x1D1D20()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    private func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(88.0)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(iconView.snp.bottom).offset(20.0)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.top.equalTo(titleLabel.snp.bottom).offset(12.0)
        }

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        let stackViews: [UIView] = [
            walletView,
            accountAddressView,
            networkView,
            networkFeeView
        ]

        for view in stackViews {
            stackView.addArrangedSubview(view)
            view.snp.makeConstraints { make in
                make.height.equalTo(48.0)
            }
        }

        addSubview(transactionDetailsControl)
        transactionDetailsControl.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(48.0)
        }

        addSubview(rejectButton)
        rejectButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(self.snp.centerX).offset(-8.0)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16.0)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.leading.equalTo(self.snp.centerX).offset(8.0)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16.0)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

extension DAppOperationConfirmViewLayout {
    private static func createIconDetailsRowView() -> RowView<GenericTitleValueView<UILabel, IconDetailsView>> {
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
    }
}
