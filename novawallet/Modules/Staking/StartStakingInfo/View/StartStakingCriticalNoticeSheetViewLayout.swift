import UIKit

final class StartStakingCriticalNoticeSheetViewLayout: UIView {
    let iconView: GenericBorderedView<UIImageView> = .create { view in
        view.contentView.image = R.image.iconWarningApp()!
        view.contentView.contentMode = .scaleAspectFit

        view.contentInsets = .init(inset: (Constants.iconContainerSize - Constants.iconSize) / 2)
        view.backgroundView.apply(style: .selectableContainer(radius: 20))
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    let bodyLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    private let buttonsStackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.spacing = 12
        view.distribution = .fillEqually
    }

    let cancelButton: TriangularedButton = .create { view in
        view.applySecondaryDefaultStyle()
    }

    let timerButton: TimerButton = .create { view in
        view.activeColor = R.color.colorButtonBackgroundReject()!
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

// MARK: - Private

private extension StartStakingCriticalNoticeSheetViewLayout {
    func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.size.equalTo(Constants.iconContainerSize)
            make.centerX.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        addSubview(bodyLabel)
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(timerButton)

        addSubview(buttonsStackView)
        buttonsStackView.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset)
        }
    }
}

// MARK: - Constants

private extension StartStakingCriticalNoticeSheetViewLayout {
    enum Constants {
        static let iconSize: CGFloat = 66
        static let iconContainerSize: CGFloat = 88
    }
}
