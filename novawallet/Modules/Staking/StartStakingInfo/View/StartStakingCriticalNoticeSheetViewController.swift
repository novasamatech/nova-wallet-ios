import UIKit
import Foundation_iOS
import UIKit_iOS

final class StartStakingCriticalNoticeSheetViewController: UIViewController, ViewHolder {
    typealias RootViewType = StartStakingCriticalNoticeSheetViewLayout

    let presenter: StartStakingCriticalNoticeSheetPresenterProtocol

    private let noticeTitle: String
    private let body: String

    init(
        presenter: StartStakingCriticalNoticeSheetPresenterProtocol,
        title: String,
        body: String
    ) {
        self.presenter = presenter
        noticeTitle = title
        self.body = body
        super.init(nibName: nil, bundle: nil)

        preferredContentSize = CGSize(width: 0.0, height: 340.0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StartStakingCriticalNoticeSheetViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.titleLabel.text = noticeTitle
        rootView.bodyLabel.text = body

        let locale = LocalizationManager.shared.selectedLocale
        let languages = locale.rLanguages
        let localizedStrings = R.string(preferredLanguages: languages).localizable
        rootView.cancelButton.imageWithTitleView?.title = localizedStrings.commonCancel()

        setupHandlers()
        presenter.setup()
    }
}

// MARK: - Private

private extension StartStakingCriticalNoticeSheetViewController {
    func setupHandlers() {
        rootView.cancelButton.addTarget(
            self,
            action: #selector(actionCancel),
            for: .touchUpInside
        )
        rootView.timerButton.addTarget(
            self,
            action: #selector(actionConfirm),
            for: .touchUpInside
        )
    }

    @objc func actionCancel() {
        presenter.cancel()
    }

    @objc func actionConfirm() {
        presenter.confirm()
    }
}

// MARK: - StartStakingCriticalNoticeSheetViewProtocol

extension StartStakingCriticalNoticeSheetViewController: StartStakingCriticalNoticeSheetViewProtocol {
    func didStartTimer(totalSeconds: Int) {
        rootView.timerButton.startTimer(totalSeconds: totalSeconds)
    }

    func didUpdateTimer(remainingSeconds: Int) {
        rootView.timerButton.updateTimerLabel(remainingSeconds: remainingSeconds)
    }

    func didFinishTimer(confirmTitle: String) {
        rootView.timerButton.finishTimer(title: confirmTitle)
    }
}

// MARK: - ModalPresenterDelegate

extension StartStakingCriticalNoticeSheetViewController: ModalPresenterDelegate {
    func presenterShouldHide(_: ModalPresenterProtocol) -> Bool { false }
    func presenterDidHide(_: ModalPresenterProtocol) {}
}
