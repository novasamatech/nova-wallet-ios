import UIKit

final class GovAddDelegationTracksViewController: GovBaseEditDelegationViewController {
    override func setupLocalization() {
        super.setupLocalization()

        editDelegationLayout?.titleLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.govAddDelegationTracksTitle()

        editDelegationLayout?.descriptionLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.govAddDelegationTracksDetails()
    }
}
