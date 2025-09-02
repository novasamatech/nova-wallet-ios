import Foundation
import Foundation_iOS

final class PayCardPresenter {
    weak var view: PayCardViewProtocol?
    let wireframe: PayCardWireframeProtocol
    let interactor: PayCardInteractorInputProtocol
    let logger: LoggerProtocol

    private let localizationManager: LocalizationManagerProtocol

    private var openCardTimestamp: TimeInterval?
    private var isCardExists: Bool = false
    private var fundingStatus: PayCardStatus?

    init(
        interactor: PayCardInteractorInputProtocol,
        wireframe: PayCardWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func showFailAlert() {
        let languages = localizationManager.selectedLocale.rLanguages

        let title = R.string.localizable.cardOpenFailedAlertTitle(preferredLanguages: languages)
        let message = R.string.localizable.cardOpenFailedAlertMessage(preferredLanguages: languages)

        let closeAction = AlertPresentableAction(
            title: R.string.localizable.commonOk(preferredLanguages: languages),
            handler: {}
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [closeAction],
            closeAction: nil
        )

        wireframe.present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }

    private func showCardPending(
        for remainedTime: TimeInterval,
        totalTime: TimeInterval
    ) {
        let timer = CountdownTimerMediator()
        timer.addObserver(self)
        timer.start(with: remainedTime)

        wireframe.showCardFundingState(
            from: view,
            mode: isCardExists ? .topup : .issue,
            timerMediator: timer,
            totalTime: totalTime,
            locale: localizationManager.selectedLocale
        )
    }
}

extension PayCardPresenter: PayCardPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func processMessage(body: Any, of name: String) {
        interactor.processMessage(body: body, of: name)
    }
}

extension PayCardPresenter: PayCardInteractorOutputProtocol {
    func didReceive(model: PayCardModel) {
        view?.didReceive(model: model)
    }

    func didRequestTopup(for model: PayCardTopupModel) {
        wireframe.showSend(from: view, with: model) { [weak self] _ in
            guard let self else {
                return
            }

            fundingStatus = nil
            interactor.processFundInit()
        }
    }

    func didReceiveCardOpenTimestamp(_ timestamp: TimeInterval) {
        openCardTimestamp = timestamp

        logger.debug("Card open timestamp \(timestamp)")
    }

    func didReceivePayStatus(_ payStatus: PayCardStatus) {
        logger.debug("Card status \(payStatus)")

        // don't change card existing state if detected once in the session
        if !isCardExists, payStatus.isCompleted {
            isCardExists = true
        }

        switch (fundingStatus, payStatus) {
        case (.failed, .completed), (.pending, .completed):
            wireframe.closeCardOpenSheet(
                from: view,
                completion: nil
            )
        case let (.none, .pending(remained, total)), let (.failed, .pending(remained, total)):
            showCardPending(for: remained, totalTime: total)
        case (.none, .failed), (.pending, .failed):
            showFailAlert()
        default:
            break
        }

        fundingStatus = payStatus
    }
}

extension PayCardPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {}

    func didCountdown(remainedInterval _: TimeInterval) {}

    func didStop(with _: TimeInterval) {
        wireframe.closeCardOpenSheet(from: view) { [weak self] in
            self?.interactor.checkPendingTimeout()
        }
    }
}
