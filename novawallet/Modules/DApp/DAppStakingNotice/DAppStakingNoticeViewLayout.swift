import UIKit
import UIKit_iOS

final class DAppStakingNoticeViewLayout: UIView {
    let iconView: DAppIconView = .create { view in
        view.backgroundView.cornerRadius = Constants.iconCornerRadius
        view.contentInsets = Constants.iconInsets

        let viewModel = StaticImageViewModel(image: R.image.iconInfoFilled()!)
        view.bind(viewModel: viewModel, size: Constants.displayIconSize)
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.textAlignment = .center
        view.numberOfLines = 1
    }

    let subtitleLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    let actionButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    let secondaryActionButton: RoundedButton = .create { view in
        view.applyTextStyle()
        view.imageWithTitleView?.titleFont = .semiBoldSubheadline
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Internal

extension DAppStakingNoticeViewLayout {
    func setSecondaryAction(title: String, prominent: Bool) {
        secondaryActionButton.imageWithTitleView?.title = title
        secondaryActionButton.imageWithTitleView?.titleColor = prominent
            ? R.color.colorButtonTextAccent()!
            : R.color.colorTextSecondary()!
        secondaryActionButton.invalidateLayout()
    }
}

// MARK: Private

private extension DAppStakingNoticeViewLayout {
    func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.iconTopInset)
            make.size.equalTo(Constants.iconSize)
            make.centerX.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(Constants.titleTopOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.subtitleTopOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(secondaryActionButton)
        secondaryActionButton.snp.makeConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset)
            make.centerX.equalToSuperview()
            make.height.equalTo(Constants.secondaryActionHeight)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.bottom.equalTo(secondaryActionButton.snp.top).offset(-Constants.actionsSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}

// MARK: Constants

private extension DAppStakingNoticeViewLayout {
    enum Constants {
        static let iconSize = CGSize(width: 88, height: 88)
        static let iconCornerRadius: CGFloat = 24.0
        static let iconInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        static let iconTopInset: CGFloat = 4.0
        static let titleTopOffset: CGFloat = 20.0
        static let subtitleTopOffset: CGFloat = 12.0
        static let actionsSpacing: CGFloat = 12.0
        static let secondaryActionHeight: CGFloat = 24.0

        static var displayIconSize: CGSize {
            CGSize(
                width: iconSize.width - iconInsets.left - iconInsets.right,
                height: iconSize.height - iconInsets.top - iconInsets.bottom
            )
        }
    }
}
