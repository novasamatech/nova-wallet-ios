import UIKit

final class AcalaContributionSetupViewLayout: CrowdloanContributionSetupViewLayout {
    typealias Button = RadioButton<AcalaContributionMethod>
    let buttons: [Button] = {
        AcalaContributionMethod.allCases.map { Button(model: $0) }
    }()

    override func setupLayout() {
        super.setupLayout()

        guard
            let titleLabelIndex = contentView.stackView.arrangedSubviews.firstIndex(of: contributionTitleLabel) else {
            return
        }

        let buttonsStack = UIView.hStack(
            distribution: .fillEqually,
            spacing: 16,
            buttons
        )

        contentView.stackView.insertArrangedSubview(buttonsStack, at: titleLabelIndex + 1)
        buttonsStack.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(44)
        }
    }

    override func applyLocalization() {
        super.applyLocalization()

        buttons.forEach { button in
            let title = button.model.title(for: locale)
            button.imageWithTitleView?.title = title
        }
    }

    func bind(selectedMethod: AcalaContributionMethod) {
        buttons.forEach { $0.isSelected = $0.model == selectedMethod }
    }
}
