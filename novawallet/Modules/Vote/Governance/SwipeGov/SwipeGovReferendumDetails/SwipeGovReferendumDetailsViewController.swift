import UIKit
import Foundation_iOS

final class SwipeGovReferendumDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwipeGovReferendumDetailsViewLayout

    let presenter: SwipeGovReferendumDetailsPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        presenter: SwipeGovReferendumDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwipeGovReferendumDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupHandlers()

        presenter.setup()
    }

    private func setupNavigationItem() {
        navigationItem.rightBarButtonItem = rootView.shareButton

        rootView.shareButton.target = self
        rootView.shareButton.action = #selector(actionShare)
    }

    private func setupHandlers() {
        rootView.accountContainerView.addTarget(
            self,
            action: #selector(actionProposer),
            for: .touchUpInside
        )

        rootView.descriptionView.delegate = self
    }

    @objc private func actionProposer() {
        presenter.showProposerDetails()
    }

    @objc private func actionShare() {
        presenter.share()
    }
}

// MARK: SwipeGovReferendumDetailsViewProtocol

extension SwipeGovReferendumDetailsViewController: SwipeGovReferendumDetailsViewProtocol {
    func didReceive(titleModel: ReferendumDetailsTitleView.Model) {
        rootView.bind(
            viewModel: titleModel,
            locale: localizationManager.selectedLocale
        )

        rootView.setNeedsLayout()
    }

    func didReceive(trackTagsModel: TrackTagsView.Model?) {
        rootView.bind(trackTagsModel: trackTagsModel)
    }

    func didReceive(activeTimeViewModel: ReferendumInfoView.Time?) {
        guard let activeTimeViewModel else {
            return
        }

        rootView.timeView.bind(viewModel: activeTimeViewModel.titleIcon)
        rootView.timeView.apply(style: activeTimeViewModel.isUrgent ? .activeTimeView : .timeView)

        if rootView.timeView.superview == nil {
            navigationItem.titleView = rootView.timeView
        }
    }
}

// MARK: MarkdownViewContainerDelegate

extension SwipeGovReferendumDetailsViewController: MarkdownViewContainerDelegate {
    func markdownView(_: MarkdownViewContainer, asksHandle url: URL) {
        presenter.openURL(url)
    }
}
