import UIKit
import UIKit_iOS
import Foundation_iOS

class GovernanceSelectTracksViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceSelectTracksViewLayout

    typealias TracksPair = ViewModelViewPair<
        GovernanceSelectTrackViewModel.Track, RowView<GovernanceSelectableTrackView>
    >

    typealias GroupsPair = ViewModelViewPair<GovernanceSelectTrackViewModel.Group, RoundedButton>

    let basePresenter: SelectTracksPresenterProtocol

    private var tracks: [TracksPair] = []
    private var groups: [GroupsPair] = []

    init(
        basePresenter: SelectTracksPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.basePresenter = basePresenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceSelectTracksViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()

        basePresenter.setup()
    }

    func setupLocalization() {
        updateActionButtonState()

        updateEmptyStateLocalization()
    }

    func updateEmptyStateLocalization() {}

    private func setupHandlers() {
        rootView.proceedButton.addTarget(
            self,
            action: #selector(actionProceed),
            for: .touchUpInside
        )
    }

    @objc private func actionProceed() {
        basePresenter.proceed()
    }

    @objc private func actionGroupTap(sender: AnyObject) {
        guard let viewModel = groups.first(where: { $0.view === sender })?.viewModel else {
            return
        }

        basePresenter.select(group: viewModel)
    }

    @objc private func actionTrackTap(sender: AnyObject) {
        guard let viewModel = tracks.first(where: { $0.view === sender })?.viewModel else {
            return
        }

        basePresenter.toggleTrackSelection(track: viewModel)
    }

    private func updateActionButtonState() {
        let hasSelectedTracks = tracks.contains { $0.viewModel.viewModel.selectable }

        let title: String

        if hasSelectedTracks {
            rootView.proceedButton.applyEnabledStyle()
            rootView.proceedButton.isUserInteractionEnabled = true

            title = R.string.localizable.commonContinue(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            rootView.proceedButton.applyDisabledStyle()
            rootView.proceedButton.isUserInteractionEnabled = false

            title = R.string.localizable.govTracksSelectionHint(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        rootView.proceedButton.imageWithTitleView?.title = title
        rootView.proceedButton.invalidateLayout()
    }

    private func apply(newGroups: [GovernanceSelectTrackViewModel.Group]) {
        rootView.clearGroupButtons(groups.map(\.view))
        groups = []

        for group in newGroups {
            let button = rootView.addGroupButton(for: group.title)
            groups.append(.init(viewModel: group, view: button))

            button.addTarget(self, action: #selector(actionGroupTap), for: .touchUpInside)
        }
    }

    private func apply(newTracks: [GovernanceSelectTrackViewModel.Track]) {
        rootView.clearTrackRows(tracks.map(\.view))
        tracks = []

        if !newTracks.isEmpty {
            rootView.clearEmptyStateView()
            rootView.setGroupsContainer(hidden: false)

            for track in newTracks {
                let trackView = rootView.addTrackRow(for: track.viewModel)
                tracks.append(.init(viewModel: track, view: trackView))

                trackView.addTarget(self, action: #selector(actionTrackTap), for: .touchUpInside)
            }
        } else {
            rootView.addEmptyStateView()
            updateEmptyStateLocalization()
            rootView.setGroupsContainer(hidden: true)
        }
    }
}

extension GovernanceSelectTracksViewController: GovernanceSelectTracksViewProtocol {
    func didReceiveTracks(viewModel: GovernanceSelectTrackViewModel) {
        apply(newGroups: viewModel.trackGroups)
        apply(newTracks: viewModel.availableTracks)

        updateActionButtonState()
    }
}

extension GovernanceSelectTracksViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
