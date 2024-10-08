import Foundation
import SoraFoundation

final class PayCardPresenter {
    weak var view: PayCardViewProtocol?
    let wireframe: PayCardWireframeProtocol
    let interactor: PayCardInteractorInputProtocol

    private let localizationManager: LocalizationManagerProtocol

    private var openCardTimestamp: TimeInterval?
    private var cardStatus: PayCardStatus?

    init(
        interactor: PayCardInteractorInputProtocol,
        wireframe: PayCardWireframeProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.localizationManager = localizationManager
    }

    private func showFailAlert() {
        let languages = localizationManager.selectedLocale.rLanguages

        let title = R.string.localizable.cardOpenFailedAlertTitle(preferredLanguages: languages)
        let message = R.string.localizable.cardOpenFailedAlertMessage(preferredLanguages: languages)

        let closeAction = AlertPresentableAction(
            title: R.string.localizable.commonOk(preferredLanguages: languages),
            handler: { [weak self] in
                self?.wireframe.close(from: self?.view)
            }
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

    private func showCardOpenPending() {
        guard let openCardTimestamp else {
            return
        }

        let timer = CountdownTimerMediator()
        timer.addObserver(self)
        timer.start(with: openCardTimestamp)

        wireframe.showCardOpenPending(
            from: view,
            timerMediator: timer,
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
            self?.interactor.processSuccessTopup()
        }
    }

    func didReceiveCardOpenTimestamp(_ timestamp: TimeInterval) {
        openCardTimestamp = timestamp
    }

    func didReceiveCardStatus(_ cardStatus: PayCardStatus) {
        switch (self.cardStatus, cardStatus) {
        case (.failed, .created), (.pending, .created):
            wireframe.closeCardOpenSheet(
                from: view,
                completion: nil
            )
        case (.none, .pending), (.failed, .pending):
            showCardOpenPending()
        case (.none, .failed), (.pending, .failed):
            showFailAlert()
        default:
            break
        }

        self.cardStatus = cardStatus
    }
}

extension PayCardPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {}

    func didCountdown(remainedInterval _: TimeInterval) {}

    func didStop(with _: TimeInterval) {
        wireframe.closeCardOpenSheet(from: view) { [weak self] in
            self?.showFailAlert()
        }
    }
}
