import UIKit

final class AcalaContributionSetupViewLayout: CrowdloanContributionSetupViewLayout {
    let switсhView: UIView = {
        let view = UIView()
        view.backgroundColor = .red
        return view
    }()

    override func setupLayout() {
        super.setupLayout()

        guard
            let titleLabelIndex = contentView.stackView.arrangedSubviews.firstIndex(of: contributionTitleLabel) else {
            return
        }

        contentView.stackView.insertArrangedSubview(switсhView, at: titleLabelIndex + 1)
        switсhView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(44)
        }
    }
}
