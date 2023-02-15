import UIKit

final class GovEditDelegationTracksViewController: GovBaseEditDelegationViewController {
    override func setupLocalization() {
        super.setupLocalization()

        editDelegationLayout?.titleLabel.text = R.string.localizable.govEditDelegationTracksTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        editDelegationLayout?.descriptionLabel.text = R.string.localizable.govAddDelegationTracksDetails(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}
