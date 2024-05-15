import Foundation

final class BackupAttentionPresenter {
    weak var view: BackupAttentionViewProtocol?
    let wireframe: BackupAttentionWireframeProtocol
    let interactor: BackupAttentionInteractorInputProtocol

    private var checkBoxViewModels: [CheckBoxIconDetailsView.Model] = []

    init(
        interactor: BackupAttentionInteractorInputProtocol,
        wireframe: BackupAttentionWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension BackupAttentionPresenter: BackupAttentionPresenterProtocol {
    func setup() {
        let initialViewModel = makeInitialViewModel()
        checkBoxViewModels = initialViewModel.rows.rows
        view?.didReceive(initialViewModel)
    }
}

extension BackupAttentionPresenter: BackupAttentionInteractorOutputProtocol {}

private extension BackupAttentionPresenter {
    func makeInitialViewModel() -> BackupAttentionViewLayout.Model {
        // TODO: Localize

        let onCheckClosure: (UUID) -> Void = { [weak self] id in
            self?.changeCheckBoxState(for: id)
            self?.updateView()
        }

        return BackupAttentionViewLayout.Model(
            rows: .init(rows: [
                .init(
                    image: R.image.iconAttentionPassphrase(),
                    text: .init(closure: { _ in
                        .raw("Having the recovery phrase means having total and permanent access to all connected wallets and the money within them.")
                    }),
                    checked: false,
                    onCheck: onCheckClosure
                ),
                .init(
                    image: R.image.iconAttentionPassphraseWrite(),
                    text: .init(closure: { _ in
                        .raw("Having the recovery phrase means having total and permanent access to all connected wallets and the money within them.")
                    }),
                    checked: false,
                    onCheck: onCheckClosure
                ),
                .init(
                    image: R.image.iconAttentionPassphraseSupport(),
                    text: .init(closure: { _ in
                        .raw("Having the recovery phrase means having total and permanent access to all connected wallets and the money within them.")
                    }),
                    checked: false,
                    onCheck: onCheckClosure
                )
            ]),
            button: .inactive
        )
    }

    func updateView() {
        let newViewModel = makeViewModel()
        view?.didReceive(newViewModel)
    }

    func makeViewModel() -> BackupAttentionViewLayout.Model {
        BackupAttentionViewLayout.Model(
            rows: .init(rows: checkBoxViewModels),
            button: checkBoxViewModels
                .filter { $0.checked }
                .count == checkBoxViewModels.count
                ? .active
                : .inactive
        )
    }

    func changeCheckBoxState(for checkBoxId: UUID) {
        guard let index = checkBoxViewModels.firstIndex(where: { $0.id == checkBoxId }) else {
            return
        }
        let current = checkBoxViewModels[index]

        checkBoxViewModels[index] = CheckBoxIconDetailsView.Model(
            image: current.image,
            text: current.text,
            checked: !current.checked,
            onCheck: current.onCheck
        )
    }
}
