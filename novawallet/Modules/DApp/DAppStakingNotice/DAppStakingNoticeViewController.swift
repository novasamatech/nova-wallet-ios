import UIKit
import Foundation_iOS

final class DAppStakingNoticeViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppStakingNoticeViewLayout

    let presenter: DAppStakingNoticePresenterProtocol

    private var isContinueRevealed: Bool = false

    init(
        presenter: DAppStakingNoticePresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0.0, height: Constants.preferredHeight)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppStakingNoticeViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }
}

// MARK: Private

private extension DAppStakingNoticeViewController {
    func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionGoToStaking),
            for: .touchUpInside
        )

        rootView.secondaryActionButton.addTarget(
            self,
            action: #selector(actionSecondary),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        let languages = selectedLocale.rLanguages

        rootView.titleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.dappStakingNoticeTitle()

        rootView.subtitleLabel.text = R.string(
            preferredLanguages: languages
        ).localizable.dappStakingNoticeMessage()

        rootView.actionButton.imageWithTitleView?.title = R.string(
            preferredLanguages: languages
        ).localizable.commonGoToStaking()

        applySecondaryActionState()
    }

    func applySecondaryActionState() {
        let languages = selectedLocale.rLanguages

        let title = if isContinueRevealed {
            R.string(preferredLanguages: languages).localizable.dappStakingNoticeContinue()
        } else {
            R.string(preferredLanguages: languages).localizable.commonAdvanced()
        }

        rootView.setSecondaryAction(title: title, prominent: isContinueRevealed)
    }

    @objc func actionGoToStaking() {
        presenter.goToStaking()
    }

    @objc func actionSecondary() {
        if isContinueRevealed {
            presenter.continueToSite()
        } else {
            isContinueRevealed = true

            UIView.transition(
                with: rootView.secondaryActionButton,
                duration: Constants.revealAnimationDuration,
                options: .transitionCrossDissolve
            ) { [weak self] in
                self?.applySecondaryActionState()
            }
        }
    }
}

// MARK: DAppStakingNoticeViewProtocol

extension DAppStakingNoticeViewController: DAppStakingNoticeViewProtocol {}

// MARK: Localizable

extension DAppStakingNoticeViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

// MARK: Constants

private extension DAppStakingNoticeViewController {
    enum Constants {
        static let preferredHeight: CGFloat = 336.0
        static let revealAnimationDuration: TimeInterval = 0.2
    }
}
