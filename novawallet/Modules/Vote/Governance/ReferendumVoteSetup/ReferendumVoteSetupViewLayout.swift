import UIKit
import UIKit_iOS

final class ReferendumVoteSetupViewLayout: BaseReferendumVoteSetupViewLayout {
    let ayeButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundApprove()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundApprove()!
        button.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconThumbsUpFilled()
        return button
    }()

    let abstainButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.cornerRadius = Constants.smallButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconAbstain()
        return button
    }()

    let nayButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundReject()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundReject()!
        button.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconThumbsDownFilled()
        return button
    }()

    override func setupLayout() {
        super.setupLayout()

        containerView.stackView.setCustomSpacing(12.0, after: titleLabel)
    }

    override func setupButtonsLayout() {
        buttonContainer.addSubview(abstainButton)
        abstainButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.smallButtonSize)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        buttonContainer.addSubview(nayButton)
        nayButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(abstainButton.snp.leading).offset(-40)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        buttonContainer.addSubview(ayeButton)
        ayeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.equalTo(abstainButton.snp.trailing).offset(40)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }
    }

    func showAbstain() {
        convictionHintView.isHidden = false
        showAbstainButton()
    }

    func hideAbstain() {
        convictionHintView.isHidden = true
        hideAbstainButton()
    }

    func showAbstainButton() {
        guard abstainButton.isHidden else {
            return
        }

        abstainButton.isHidden = false

        nayButton.snp.remakeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(abstainButton.snp.leading).offset(-40)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        ayeButton.snp.remakeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.equalTo(abstainButton.snp.trailing).offset(40)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        abstainButton.snp.remakeConstraints { make in
            make.size.equalTo(Constants.smallButtonSize)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        nayButton.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        ayeButton.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
    }

    func hideAbstainButton() {
        guard !abstainButton.isHidden else {
            return
        }

        abstainButton.isHidden = true

        nayButton.snp.remakeConstraints { make in
            make.height.equalTo(52)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(snp.centerX).offset(-8)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        ayeButton.snp.remakeConstraints { make in
            make.height.equalTo(52)
            make.leading.equalTo(snp.centerX).offset(8)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        nayButton.roundedBackgroundView?.cornerRadius = 12
        ayeButton.roundedBackgroundView?.cornerRadius = 12
    }
}
