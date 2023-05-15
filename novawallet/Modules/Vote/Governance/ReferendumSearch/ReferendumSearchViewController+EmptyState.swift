import UIKit
import SoraFoundation
import SoraUI

extension ReferendumSearchViewController {
    enum EmptyState {
        case notFound
        case start
    }
}

extension ReferendumSearchViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension ReferendumSearchViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let emptyStateType = emptyStateType else {
            return nil
        }

        let emptyView = EmptyStateView()

        switch emptyStateType {
        case .notFound:
            emptyView.image = R.image.iconEmptySearch()
            emptyView.title = R.string.localizable.governanceReferendumsSearchEmpty(preferredLanguages: selectedLocale.rLanguages)
        case .start:
            emptyView.image = R.image.iconStartSearch()
            emptyView.title = R.string.localizable.commonSearchStartTitle_v2_2_0(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .p2Paragraph

        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.emptyStateContainer
    }

    var verticalSpacingForEmptyState: CGFloat? { 0 }
}

extension ReferendumSearchViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        emptyStateType != nil
    }
}
