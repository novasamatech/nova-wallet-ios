import UIKit

final class GovRevokeDelegationTracksViewController: GovernanceSelectTracksViewController {
    override func setupLocalization() {
        super.setupLocalization()

        rootView.titleLabel.text = R.string.localizable.govRevokeDelegationTracksTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}
