import UIKit

final class GovAddDelegationTracksViewController: GovBaseEditDelegationViewController {
    override func setupLocalization() {
        super.setupLocalization()

        editDelegationLayout?.titleLabel.text = R.string.localizable.govAddDelegationTracksTitle(
            preferredLanguages: selectedLocale.rLanguages
        )

        editDelegationLayout?.descriptionLabel.text = R.string.localizable.govAddDelegationTracksDetails(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}
