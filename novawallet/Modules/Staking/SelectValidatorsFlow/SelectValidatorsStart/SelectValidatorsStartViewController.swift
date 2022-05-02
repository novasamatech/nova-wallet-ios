import UIKit
import SoraUI
import SoraFoundation

final class SelectValidatorsStartViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    enum Phase {
        case setup
        case update
    }

    typealias RootViewType = SelectValidatorsViewLayout

    let presenter: SelectValidatorsStartPresenterProtocol
    let phase: Phase

    private var viewModel: SelectValidatorsStartViewModel?

    private var viewModelIsSet: Bool {
        viewModel != nil
    }

    init(
        presenter: SelectValidatorsStartPresenterProtocol,
        phase: Phase,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.phase = phase

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SelectValidatorsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        updateLoadingState()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.updateOnAppearance()
    }

    private func configure() {
        rootView.bannerView.actionButton?.addTarget(
            self,
            action: #selector(actionRecommendedValidators),
            for: .touchUpInside
        )

        rootView.bannerView.linkButton?.addTarget(
            self,
            action: #selector(actionLearnMore),
            for: .touchUpInside
        )

        rootView.customValidatorsCell.addTarget(
            self,
            action: #selector(actionCustomValidators),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.bannerView.infoView.titleLabel.text = R.string.localizable.stakingRecommendedBannerTitle(
            preferredLanguages: languages
        )

        rootView.bannerView.infoView.subtitleLabel.text = R.string.localizable.stakingRecommendedBannerMessage(
            preferredLanguages: languages
        )

        rootView.bannerView.linkButton?.imageWithTitleView?.title = R.string.localizable.commonHowItWorks(
            preferredLanguages: languages
        )

        rootView.bannerView.actionButton?.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )

        rootView.customValidatorsCell.titleLabel.text = R.string.localizable
            .stakingSelectValidatorsCustomButtonTitle(preferredLanguages: languages)

        switch phase {
        case .setup:
            title = R.string.localizable.stakingSetValidators(preferredLanguages: languages)
        case .update:
            title = R.string.localizable.stakingChangeValidators(preferredLanguages: languages)
        }

        updateSelected()
    }

    private func toggleActivityViews() {
        if viewModelIsSet {
            rootView.bannerView.stopLoading()
        } else {
            rootView.bannerView.startLoading()
        }
    }

    private func toggleNextStepIndicators() {
        if viewModelIsSet {
            rootView.customValidatorsCell.rowContentView.alpha = 1.0
            rootView.customValidatorsCell.isUserInteractionEnabled = true
        } else {
            rootView.customValidatorsCell.rowContentView.alpha = 0.5
            rootView.customValidatorsCell.isUserInteractionEnabled = false
        }
    }

    func updateLoadingState() {
        toggleActivityViews()
        toggleNextStepIndicators()
    }

    private func updateSelected() {
        guard let viewModel = viewModel else {
            rootView.customValidatorsCell.detailsLabel.text = ""
            return
        }

        if viewModel.selectedCount > 0 {
            let languages = selectedLocale.rLanguages
            let text = R.string.localizable
                .stakingValidatorInfoNominators(
                    "\(viewModel.selectedCount)",
                    "\(viewModel.totalCount)",
                    preferredLanguages: languages
                )
            rootView.customValidatorsCell.detailsLabel.text = text
        } else {
            rootView.customValidatorsCell.detailsLabel.text = ""
        }
    }

    @objc private func actionRecommendedValidators() {
        presenter.selectRecommendedValidators()
    }

    @objc private func actionCustomValidators() {
        presenter.selectCustomValidators()
    }

    @objc private func actionLearnMore() {
        presenter.selectLearnMore()
    }
}

extension SelectValidatorsStartViewController: SelectValidatorsStartViewProtocol {
    func didReceive(viewModel: SelectValidatorsStartViewModel) {
        self.viewModel = viewModel

        updateLoadingState()
        updateSelected()
    }
}

extension SelectValidatorsStartViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
