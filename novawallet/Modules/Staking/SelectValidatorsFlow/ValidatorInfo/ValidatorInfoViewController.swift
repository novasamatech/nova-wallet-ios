import UIKit
import SoraFoundation
import SoraUI

class ValidatorInfoViewController: UIViewController, ViewHolder, LoadableViewProtocol {
    typealias RootViewType = ValidatorInfoViewLayout

    let presenter: ValidatorInfoPresenterProtocol

    struct LinkPair {
        let view: UIView
        let item: ValidatorInfoViewModel.IdentityItem
    }

    private var linkPairs: [LinkPair] = []

    private var state: ValidatorInfoState?

    // MARK: Lifecycle -

    init(presenter: ValidatorInfoPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ValidatorInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        applyTitle()
    }

    func applyTitle() {
        title = R.string.localizable.stakingValidatorInfoTitle(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    func applyState() {
        guard let state = state else {
            return
        }

        didStopLoading()

        switch state {
        case .empty:
            rootView.contentView.isHidden = true
        case .error:
            rootView.contentView.isHidden = true
        case .loading:
            rootView.contentView.isHidden = true
            didStartLoading()
        case let .validatorInfo(viewModel):
            rootView.contentView.isHidden = false
            apply(viewModel: viewModel)
        }

        reloadEmptyState(animated: true)
    }

    func applyAccountView(from viewModel: ValidatorInfoViewModel) {
        let accountView = rootView.addWalletAccountView(for: viewModel.account)

        accountView.addTarget(self, action: #selector(actionOnAccount), for: .touchUpInside)
    }

    func applyNominatorsView(from exposure: ValidatorInfoViewModel.Exposure) {
        let nominatorsTitle = R.string.localizable.stakingValidatorNominators(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.addNominatorsView(exposure, title: nominatorsTitle)
    }

    func applyEstimatedReward(_ estimatedReward: String) {
        if let stakingTableView = rootView.stakingTableView {
            rootView.addTitleValueView(
                for: R.string.localizable.stakingValidatorEstimatedReward(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                value: estimatedReward,
                to: stakingTableView
            )
        }
    }

    func apply(viewModel: ValidatorInfoViewModel) {
        rootView.clearStackView()
        linkPairs = []

        applyAccountView(from: viewModel)

        addSlashedAlertIfNeeded(for: viewModel)

        addOversubscriptionAlertIfNeeded(for: viewModel.staking)

        rootView.addStakingSection(
            with: R.string.localizable.stakingTitle(preferredLanguages: selectedLocale.rLanguages)
        )

        rootView.addStakingStatusView(viewModel.staking, locale: selectedLocale)

        if case let .elected(exposure) = viewModel.staking.status {
            applyNominatorsView(from: exposure)

            let totalStakeView = rootView.addTotalStakeView(exposure, locale: selectedLocale)
            totalStakeView.addTarget(self, action: #selector(actionOnTotalStake), for: .touchUpInside)

            if let minStake = exposure.minRewardableStake {
                rootView.addMinimumStakeView(minStake, locale: selectedLocale)
            }

            applyEstimatedReward(exposure.estimatedReward)
        }

        if let identityItems = viewModel.identity, !identityItems.isEmpty {
            rootView.addIdentitySection(
                with: R.string.localizable.identityTitle(preferredLanguages: selectedLocale.rLanguages)
            )

            identityItems.forEach { item in
                switch item.value {
                case let .link(value, _):
                    addLinkView(for: item, title: item.title, value: value)
                case let .text(text):
                    if let identityTableView = rootView.identityTableView {
                        rootView.addTitleValueView(for: item.title, value: text, to: identityTableView)
                    }
                }
            }
        }
    }

    private func addSlashedAlertIfNeeded(for model: ValidatorInfoViewModel) {
        if model.staking.slashed {
            let text = R.string.localizable.stakingValidatorSlashedDesc(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.addErrorView(message: text)
        }
    }

    private func addOversubscriptionAlertIfNeeded(for model: ValidatorInfoViewModel.Staking) {
        if case let .elected(exposure) = model.status, exposure.oversubscribed {
            let message: String = {
                if let myNomination = exposure.myNomination, !myNomination.isRewarded {
                    return R.string.localizable.stakingValidatorMyOversubscribedMessage(
                        preferredLanguages: selectedLocale.rLanguages
                    )
                } else {
                    return R.string.localizable.stakingValidatorOtherOversubscribedMessage(
                        preferredLanguages: selectedLocale.rLanguages
                    )
                }
            }()

            rootView.addWarningView(message: message)
        }
    }

    private func addLinkView(for item: ValidatorInfoViewModel.IdentityItem, title: String, value: String) {
        let itemView = rootView.addIdentityLinkView(for: title, url: value)
        linkPairs.append(LinkPair(view: itemView, item: item))

        itemView.addTarget(
            self,
            action: #selector(actionOnIdentityLink(_:)),
            for: .touchUpInside
        )
    }

    @objc private func actionOnAccount() {
        presenter.presentAccountOptions()
    }

    @objc private func actionOnTotalStake() {
        presenter.presentTotalStake()
    }

    @objc private func actionOnIdentityLink(_ sender: UIControl) {
        guard let linkPair = linkPairs.first(where: { $0.view === sender }) else {
            return
        }

        presenter.presentIdentityItem(linkPair.item.value)
    }
}

// MARK: - ValidatorInfoViewProtocol

extension ValidatorInfoViewController: ValidatorInfoViewProtocol {
    func didRecieve(state: ValidatorInfoState) {
        self.state = state

        applyState()
    }
}

extension ValidatorInfoViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension ValidatorInfoViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let state = state else { return nil }

        switch state {
        case let .error(error):
            let errorView = ErrorStateView()
            errorView.errorDescriptionLabel.text = error
            errorView.delegate = self
            errorView.locale = selectedLocale
            return errorView
        case .loading, .validatorInfo, .empty:
            return nil
        }
    }
}

extension ValidatorInfoViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let state = state else { return false }
        switch state {
        case .error:
            return true
        case .loading, .validatorInfo, .empty:
            return false
        }
    }
}

extension ValidatorInfoViewController: ErrorStateViewDelegate {
    func didRetry(errorView _: ErrorStateView) {
        presenter.reload()
    }
}

// MARK: - Localizable

extension ValidatorInfoViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
