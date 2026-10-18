import UIKit
import Foundation_iOS

final class StartStakingInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = StartStakingInfoViewLayout

    let presenter: StartStakingInfoPresenterProtocol
    private var viewModel: LoadableViewModelState<StartStakingViewModel>?
    private var balance = ""

    let themeColor: UIColor
    let secondaryActionTitle: LocalizableResource<String>?

    init(
        presenter: StartStakingInfoPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        themeColor: UIColor,
        secondaryActionTitle: LocalizableResource<String>? = nil
    ) {
        self.presenter = presenter
        self.themeColor = themeColor
        self.secondaryActionTitle = secondaryActionTitle

        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let headerStyle = ParagraphView.Style.createHeaderStyle(for: themeColor)
        let paragraphStyle = ParagraphView.Style.createParagraphStyle(for: themeColor)

        let layout = StartStakingInfoViewLayout(
            headerStyle: headerStyle,
            paragraphStyle: paragraphStyle,
            hasSecondaryAction: secondaryActionTitle != nil
        )

        view = layout
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()
        presenter.setup()
    }

    private func setupLocalization() {
        rootView.updateBalanceButton(
            text: balance,
            locale: selectedLocale
        )

        if let secondaryActionTitle {
            rootView.updateSecondaryButton(title: secondaryActionTitle.value(for: selectedLocale))
        }

        guard let viewModel = viewModel?.value else {
            return
        }

        rootView.updateContent(
            title: viewModel.title,
            caption: viewModel.caption,
            paragraphs: viewModel.paragraphs,
            wikiUrl: viewModel.wikiUrl,
            termsUrl: viewModel.termsUrl
        )
    }

    private func setupHandlers() {
        rootView.actionView.actionButton.addTarget(self, action: #selector(startStakingAction), for: .touchUpInside)
        rootView.secondaryButton?.addTarget(self, action: #selector(secondaryAction), for: .touchUpInside)

        rootView.onAnnouncementLinkTap = { [weak self] in
            self?.presenter.selectAnnouncementLink()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if viewModel?.isLoading == true {
            rootView.updateLoadingState()
            rootView.skeletonView?.restartSkrulling()
        }
    }

    @objc private func startStakingAction() {
        presenter.startStaking()
    }

    @objc private func secondaryAction() {
        presenter.selectSecondaryAction()
    }
}

extension StartStakingInfoViewController: StartStakingInfoViewProtocol {
    func didReceive(viewModel: LoadableViewModelState<StartStakingViewModel>) {
        switch viewModel {
        case .loading:
            rootView.startLoadingIfNeeded()
            rootView.actionView.startLoading()
            rootView.secondaryButton?.isEnabled = false
        case let .cached(value), let .loaded(value):
            rootView.stopLoadingIfNeeded()
            rootView.actionView.stopLoading()
            rootView.secondaryButton?.isEnabled = true
            rootView.updateContent(
                title: value.title,
                caption: value.caption,
                paragraphs: value.paragraphs,
                wikiUrl: value.wikiUrl,
                termsUrl: value.termsUrl
            )
        }

        self.viewModel = viewModel
    }

    func didReceive(balance: String) {
        self.balance = balance
        rootView.updateBalanceButton(text: balance, locale: selectedLocale)
    }

    func didReceive(announcement: AnnouncementViewModel?) {
        rootView.setAnnouncement(viewModel: announcement)
    }
}

extension StartStakingInfoViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else {
            return
        }
        setupLocalization()
    }
}
