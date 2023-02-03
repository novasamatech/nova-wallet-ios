import UIKit
import SoraUI

final class GovernanceSelectTracksViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceSelectTracksViewLayout

    let presenter: GovernanceSelectTracksPresenterProtocol

    private var tracks: [ViewModelViewPair<GovernanceSelectTrackViewModel.Track, RowView<GovernanceSelectableTrackView>>] = []
    private var groups: [ViewModelViewPair<GovernanceSelectTrackViewModel.Group, RoundedButton>] = []

    init(presenter: GovernanceSelectTracksPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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

        presenter.setup()
    }

    @objc private func actionGroupTap(sender: AnyObject) {
        guard let viewModel = groups.first(where: { $0.view === sender })?.viewModel else {
            return
        }

        presenter.select(group: viewModel)
    }

    @objc private func actionTrackTap(sender: AnyObject) {
        guard let viewModel = tracks.first(where: { $0.view === sender })?.viewModel else {
            return
        }

        presenter.select(track: viewModel)
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

        for track in newTracks {
            let trackView = rootView.addTrackRow(for: track.viewModel)
            tracks.append(.init(viewModel: track, view: trackView))

            trackView.addTarget(self, action: #selector(actionTrackTap), for: .touchUpInside)
        }
    }
}

extension GovernanceSelectTracksViewController: GovernanceSelectTracksViewProtocol {
    func didReceiveTracks(viewModel: GovernanceSelectTrackViewModel) {
        apply(newGroups: viewModel.trackGroups)
        apply(newTracks: viewModel.availableTracks)
    }
}
