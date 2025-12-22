import Foundation
import Foundation_iOS

final class AccountConfirmPresenter {
    weak var view: AccountConfirmViewProtocol?
    let wireframe: AccountConfirmWireframeProtocol
    let interactor: AccountConfirmInteractorInputProtocol

    private let localizationManager: LocalizationManagerProtocol
    private let mnemonicViewModelFactory: MnemonicViewModelFactory

    init(
        wireframe: AccountConfirmWireframeProtocol,
        interactor: AccountConfirmInteractorInputProtocol,
        mnemonicViewModelFactory: MnemonicViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.mnemonicViewModelFactory = mnemonicViewModelFactory
        self.localizationManager = localizationManager
    }
}

extension AccountConfirmPresenter: AccountConfirmPresenterProtocol {
    func setup() {
        interactor.requestWords()
    }

    func requestWords() {
        interactor.requestWords()
    }

    func confirm(words: [String]) {
        interactor.confirm(words: words)
    }

    func skip() {
        interactor.skipConfirmation()
    }
}

extension AccountConfirmPresenter: AccountConfirmInteractorOutputProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
        if afterConfirmationFail {
            let locale = localizationManager.selectedLocale
            let title = R.string(preferredLanguages: locale.rLanguages).localizable
                .confirmMnemonicMismatchErrorTitle()
            let message = R.string(preferredLanguages: locale.rLanguages).localizable
                .confirmMnemonicMismatchErrorMessage()
            let close = R.string(preferredLanguages: locale.rLanguages).localizable.commonOk()

            wireframe.present(
                message: message,
                title: title,
                closeAction: close,
                from: view
            )
        }

        view?.update(
            with: mnemonicViewModelFactory.createEmptyMnemonicCardViewModel(for: words),
            gridUnits: mnemonicViewModelFactory.createMnemonicGridViewModel(for: words),
            afterConfirmationFail: afterConfirmationFail
        )
    }

    func didCompleteConfirmation() {
        wireframe.proceed(from: view)
    }

    func didReceive(error: Error) {
        let locale = localizationManager.selectedLocale

        guard !wireframe.present(error: error, from: view, locale: locale) else {
            return
        }

        _ = wireframe.present(
            error: CommonError.undefined,
            from: view,
            locale: locale
        )
    }
}
