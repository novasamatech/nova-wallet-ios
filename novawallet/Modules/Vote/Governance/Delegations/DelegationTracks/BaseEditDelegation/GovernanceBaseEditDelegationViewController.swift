import UIKit
import Foundation_iOS

class GovBaseEditDelegationViewController: GovernanceSelectTracksViewController {
    var editDelegationLayout: GovernanceBaseEditDelegationLayout? {
        rootView as? GovernanceBaseEditDelegationLayout
    }

    var presenter: GovernanceBaseEditDelegationPresenterProtocol? {
        basePresenter as? GovernanceBaseEditDelegationPresenterProtocol
    }

    init(
        presenter: GovernanceBaseEditDelegationPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceBaseEditDelegationLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
    }

    override func setupLocalization() {
        super.setupLocalization()

        editDelegationLayout?.availableTracksLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govAvailableTracks()

        let unavailableButton = editDelegationLayout?.unavailableTracksButton
        unavailableButton?.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govUnavailableTracks()

        editDelegationLayout?.unavailableTracksButton.invalidateLayout()
    }

    override func updateEmptyStateLocalization() {
        editDelegationLayout?.emptyStateView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govAddDelegationTracksEmpty()
    }

    private func setupHandlers() {
        editDelegationLayout?.unavailableTracksButton.addTarget(
            self,
            action: #selector(actionUnavailableButtonTap),
            for: .touchUpInside
        )
    }

    @objc private func actionUnavailableButtonTap() {
        presenter?.showUnavailableTracks()
    }
}

extension GovBaseEditDelegationViewController: GovernanceBaseEditDelegationViewProtocol {
    func didReceive(hasUnavailableTracks: Bool) {
        editDelegationLayout?.unavailableTracksView.isHidden = !hasUnavailableTracks
    }
}
