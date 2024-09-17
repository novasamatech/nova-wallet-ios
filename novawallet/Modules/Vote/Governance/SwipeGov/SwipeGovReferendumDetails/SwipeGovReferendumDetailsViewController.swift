import UIKit
import SoraFoundation

final class SwipeGovReferendumDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwipeGovReferendumDetailsViewLayout

    let presenter: SwipeGovReferendumDetailsPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    let timeView: IconDetailsView = .create {
        $0.mode = .detailsIcon
        $0.detailsLabel.numberOfLines = 1
        $0.spacing = 5
        $0.apply(style: .timeView)
    }

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

        setupHandlers()

        presenter.setup()
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

        timeView.bind(viewModel: activeTimeViewModel.titleIcon)
        timeView.apply(style: activeTimeViewModel.isUrgent ? .activeTimeView : .timeView)

        if timeView.superview == nil {
            let barButtonItem: UIBarButtonItem? = .init(customView: timeView)
            navigationItem.setRightBarButton(barButtonItem, animated: true)
        }
    }
}

// MARK: MarkdownViewContainerDelegate

extension SwipeGovReferendumDetailsViewController: MarkdownViewContainerDelegate {
    func markdownView(_: MarkdownViewContainer, asksHandle url: URL) {
        presenter.openURL(url)
    }
}
