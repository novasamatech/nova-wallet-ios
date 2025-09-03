import UIKit

final class GovEditDelegationTracksViewController: GovBaseEditDelegationViewController {
    override func setupLocalization() {
        super.setupLocalization()

        editDelegationLayout?.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govEditDelegationTracksTitle()

        editDelegationLayout?.descriptionLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govAddDelegationTracksDetails()
    }
}
