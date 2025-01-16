import UIKit
import Foundation_iOS

final class GovernanceDelegateInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceDelegateInfoViewLayout

    let presenter: GovernanceDelegateInfoPresenterProtocol

    private var linkPairs: [ValidatorInfoViewController.LinkPair] = []

    init(presenter: GovernanceDelegateInfoPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceDelegateInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable.delegationsInfoTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    @objc private func actionReadMore() {
        presenter.presentFullDescription()
    }

    @objc private func actionDelegations() {
        presenter.presentDelegations()
    }

    @objc private func actionRecentVotes() {
        presenter.presentRecentVotes()
    }

    @objc private func actionAllVotes() {
        presenter.presentAllVotes()
    }

    @objc private func actionAddDelegation() {
        presenter.addDelegation()
    }

    @objc private func actionEditDelegation() {
        presenter.editDelegation()
    }

    @objc private func actionRevokeDelegation() {
        presenter.revokeDelegation()
    }

    @objc private func actionAccountOptions() {
        presenter.presentAccountOptions()
    }

    @objc private func actionTracks() {
        presenter.showTracks()
    }

    @objc private func actionIdentityItem(_ sender: AnyObject) {
        guard let item = linkPairs.first(where: { $0.view === sender })?.item else {
            return
        }

        presenter.presentIdentityItem(item.value)
    }
}

extension GovernanceDelegateInfoViewController: GovernanceDelegateInfoViewProtocol {
    func didReceiveDelegate(viewModel: GovernanceDelegateInfoViewModel.Delegate) {
        if let profile = viewModel.profileViewModel {
            rootView.addProfileView(for: profile, locale: selectedLocale)
        }

        let readMoreButton = rootView.addDescription(from: viewModel, delegate: self, locale: selectedLocale)
        readMoreButton?.addTarget(self, action: #selector(actionReadMore), for: .touchUpInside)

        let addressView = rootView.addAddressView(for: viewModel.addressViewModel)
        addressView.addTarget(self, action: #selector(actionAccountOptions), for: .touchUpInside)
    }

    func didReceiveStats(viewModel: GovernanceDelegateInfoViewModel.Stats) {
        let statsTable = rootView.addStatsTable(for: selectedLocale)

        if let delegatedVotes = viewModel.delegatedVotes {
            statsTable.addTitleValueCell(
                for: R.string.localizable.delegationsDelegatedVotes(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                value: delegatedVotes
            )
        }

        if let delegations = viewModel.delegations {
            let cell = statsTable.addInfoCell(
                for: R.string.localizable.delegationsDelegations(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                value: delegations
            )

            cell.addTarget(self, action: #selector(actionDelegations), for: .touchUpInside)
        }

        if let recentVotes = viewModel.recentVotes {
            let cell = statsTable.addInfoCell(
                for: R.string.localizable.delegationsLastVoted(
                    recentVotes.period,
                    preferredLanguages: selectedLocale.rLanguages
                ),
                value: recentVotes.value
            )

            cell.addTarget(self, action: #selector(actionRecentVotes), for: .touchUpInside)
        }

        if let allVotes = viewModel.allVotes {
            let cell = statsTable.addInfoCell(
                for: R.string.localizable.delegationsInfoVotedAll(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                value: allVotes
            )

            cell.addTarget(self, action: #selector(actionAllVotes), for: .touchUpInside)
        }
    }

    func didReceiveYourDelegation(viewModel: GovernanceDelegateInfoViewModel.YourDelegation?) {
        if let viewModel = viewModel {
            rootView.removeDelegationButton()

            rootView.addYourDelegationTable(for: selectedLocale)

            if let cell = rootView.addTracksCell(for: viewModel.tracks, locale: selectedLocale) {
                cell.addTarget(
                    self,
                    action: #selector(actionTracks),
                    for: .touchUpInside
                )
            }

            if let delegation = viewModel.delegation {
                rootView.addYourDelegationCell(for: delegation, locale: selectedLocale)
            }

            let actionsCell = rootView.addYourDelegationActions(for: selectedLocale)

            actionsCell.mainButton.addTarget(
                self,
                action: #selector(actionEditDelegation),
                for: .touchUpInside
            )

            actionsCell.secondaryButton.addTarget(
                self,
                action: #selector(actionRevokeDelegation),
                for: .touchUpInside
            )
        } else {
            rootView.removeYourDelegationTable()

            let addDelegationButton = rootView.addDelegationButton(for: selectedLocale)
            addDelegationButton?.addTarget(self, action: #selector(actionAddDelegation), for: .touchUpInside)
        }
    }

    func didReceiveIdentity(items: [ValidatorInfoViewModel.IdentityItem]?) {
        if let items = items {
            let table = rootView.addIdentityTable(for: selectedLocale)

            linkPairs = []

            for item in items {
                switch item.value {
                case let .link(url, _):
                    let cell = table.addLinkCell(for: item.title, url: url)
                    linkPairs.append(.init(view: cell.actionButton, item: item))

                    cell.actionButton.addTarget(
                        self,
                        action: #selector(actionIdentityItem),
                        for: .touchUpInside
                    )
                case let .text(value):
                    let cell = table.addTitleValueCell(for: item.title, value: value)
                    linkPairs.append(.init(view: cell, item: item))
                }
            }
        }
    }
}

extension GovernanceDelegateInfoViewController: MarkdownViewContainerDelegate {
    func markdownView(_: MarkdownViewContainer, asksHandle url: URL) {
        presenter.open(url: url)
    }
}

extension GovernanceDelegateInfoViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
