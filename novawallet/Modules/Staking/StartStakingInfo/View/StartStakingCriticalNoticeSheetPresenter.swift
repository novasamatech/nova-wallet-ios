import Foundation
import Foundation_iOS

final class StartStakingCriticalNoticeSheetPresenter {
    weak var view: StartStakingCriticalNoticeSheetViewProtocol?

    let onCancel: () -> Void
    let onContinue: () -> Void

    private var timer: Timer?
    private var remainingSeconds: Int
    private let countdownDuration: Int

    private static let criticalNoticeCountdownDuration: Int = 10

    init(
        onCancel: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        countdownDuration: Int = StartStakingCriticalNoticeSheetPresenter.criticalNoticeCountdownDuration
    ) {
        self.onCancel = onCancel
        self.onContinue = onContinue
        self.countdownDuration = countdownDuration
        remainingSeconds = countdownDuration
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Private

private extension StartStakingCriticalNoticeSheetPresenter {
    func startTimer() {
        remainingSeconds = countdownDuration
        view?.didStartTimer(totalSeconds: countdownDuration)

        timer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.timerTick()
        }
    }

    func timerTick() {
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            invalidateTimer()
            let locale = LocalizationManager.shared.selectedLocale
            let languages = locale.rLanguages
            let confirmTitle = R.string(preferredLanguages: languages).localizable.commonContinue()
            view?.didFinishTimer(confirmTitle: confirmTitle)
        } else {
            view?.didUpdateTimer(remainingSeconds: remainingSeconds)
        }
    }

    func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - StartStakingCriticalNoticeSheetPresenterProtocol

extension StartStakingCriticalNoticeSheetPresenter: StartStakingCriticalNoticeSheetPresenterProtocol {
    func setup() {
        startTimer()
    }

    func cancel() {
        invalidateTimer()
        view?.controller.dismiss(animated: true) { [weak self] in
            self?.onCancel()
        }
    }

    func confirm() {
        view?.controller.dismiss(animated: true) { [weak self] in
            self?.onContinue()
        }
    }
}
