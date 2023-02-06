import UIKit
import SoraFoundation

final class GovUnavailableTracksViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceUnavailableTracksViewLayout

    let presenter: GovernanceUnavailableTracksPresenterProtocol

    init(
        presenter: GovernanceUnavailableTracksPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceUnavailableTracksViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupScrollView()

        presenter.setup()
    }

    private func setupScrollView() {
        rootView.contentView.scrollView.delegate = self
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.govUnavailableTracks(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.delegatedTracksTitleLabel?.text = R.string.localizable.govUnavailableTracksDelegated(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.votedTracksTitleLabel?.text = R.string.localizable.govUnavailableTracksVoted(
            preferredLanguages: selectedLocale.rLanguages
        )

        rootView.removeVotesButton?.imageWithTitleView?.title =
            R.string.localizable.govUnavailableTracksRemoveVotes(
                preferredLanguages: selectedLocale.rLanguages
            )

        rootView.removeVotesButton?.invalidateLayout()
    }

    @objc private func actionRemoveVotes() {
        presenter.removeVotes()
    }
}

extension GovUnavailableTracksViewController: GovernanceUnavailableTracksViewProtocol {
    func didReceive(
        votedTracks: [ReferendumInfoView.Track],
        delegatedTracks: [ReferendumInfoView.Track]
    ) {
        rootView.removeTracks()

        if !delegatedTracks.isEmpty {
            rootView.addDelegatedTracks(delegatedTracks)
        }

        if !votedTracks.isEmpty {
            rootView.addVotedTracks(votedTracks)
        }

        rootView.removeVotesButton?.addTarget(
            self,
            action: #selector(actionRemoveVotes),
            for: .touchUpInside
        )

        setupLocalization()
    }
}

extension GovUnavailableTracksViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.bounces = scrollView.contentOffset.y > UIConstants.bouncesOffset
    }
}

extension GovUnavailableTracksViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension GovUnavailableTracksViewController {
    static func estimatePreferredHeight(
        for votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal]
    ) -> CGFloat {
        RootViewType.estimatePreferredHeight(
            for: votedTracks,
            delegatedTracks: delegatedTracks
        )
    }
}
