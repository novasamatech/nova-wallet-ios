import Foundation
import Foundation_iOS
import UIKit_iOS

final class GovernanceAddDelegationTracksWireframe: GovernanceSelectTracksWireframe,
    GovAddDelegationTracksWireframeProtocol {
    let state: GovernanceSharedState
    let delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>

    init(state: GovernanceSharedState, delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<AccountId>) {
        self.state = state
        self.delegateDisplayInfo = delegateDisplayInfo
    }

    func presentUnavailableTracks(
        from view: ControllerBackedProtocol?,
        delegate: GovernanceUnavailableTracksDelegate,
        votedTracks: [GovernanceTrackInfoLocal],
        delegatedTracks: [GovernanceTrackInfoLocal]
    ) {
        guard
            let presentingView = GovernanceUnavailableTracksViewFactory.createView(
                for: state,
                delegate: delegate,
                votedTracks: votedTracks,
                delegatedTracks: delegatedTracks
            ) else {
            return
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        presentingView.controller.modalTransitioningFactory = factory
        presentingView.controller.modalPresentationStyle = .custom

        view?.controller.present(presentingView.controller, animated: true)
    }

    func showRemoveVotesRequest(
        from view: ControllerBackedProtocol?,
        tracksCount: Int,
        skipClosure: @escaping () -> Void,
        removeVotesClosure: @escaping () -> Void
    ) {
        let title = LocalizableResource { locale in
            R.string.localizable.govRemoveVotesAskTitle(preferredLanguages: locale.rLanguages)
        }

        let message = LocalizableResource { locale in
            let tracksString = R.string.localizable.commonInTracks(
                format: tracksCount,
                preferredLanguages: locale.rLanguages
            )

            return R.string.localizable.govRemoveVotesAskDetails(
                tracksString,
                preferredLanguages: locale.rLanguages
            )
        }

        let skipAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string.localizable.commonSkip(preferredLanguages: locale.rLanguages)
            },
            handler: skipClosure
        )

        let removeVotesAction = MessageSheetAction(
            title: LocalizableResource { locale in
                R.string.localizable.govRemoveVotes(preferredLanguages: locale.rLanguages)
            },
            handler: removeVotesClosure
        )

        let viewModel = TitleDetailsSheetViewModel(
            title: title,
            message: message,
            mainAction: removeVotesAction,
            secondaryAction: skipAction
        )

        let bottomSheet = TitleDetailsSheetViewFactory.createView(
            from: viewModel,
            allowsSwipeDown: false,
            preferredContentSize: CGSize(width: 0, height: 200)
        )

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        bottomSheet.controller.modalTransitioningFactory = factory
        bottomSheet.controller.modalPresentationStyle = .custom

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func showRemoveVotes(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    ) {
        guard
            let removeVotesView = GovernanceRemoveVotesConfirmViewFactory.createView(
                for: state,
                tracks: tracks
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            removeVotesView.controller,
            animated: true
        )
    }

    override func proceed(
        from view: ControllerBackedProtocol?,
        tracks: [GovernanceTrackInfoLocal]
    ) {
        let newDelegateInfo = GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>(
            additions: tracks,
            delegateMetadata: delegateDisplayInfo.delegateMetadata,
            delegateIdentity: delegateDisplayInfo.delegateIdentity
        )

        guard
            let setupView = GovernanceDelegateSetupViewFactory.createAddDelegationView(
                for: state,
                delegateId: delegateDisplayInfo.additions,
                delegateDisplayInfo: newDelegateInfo
            ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            setupView.controller,
            animated: true
        )
    }
}
