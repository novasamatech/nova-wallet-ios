import Foundation
import UIKit
import Foundation_iOS

final class CollatorStkPartialUnstakeSetupVC: CollatorStkBaseUnstakeSetupVC<CollatorStkPartialUnstakeSetupLayout> {
    var presenter: CollatorStkPartialUnstakeSetupPresenterProtocol? {
        basePresenter as? CollatorStkPartialUnstakeSetupPresenterProtocol
    }

    init(
        presenter: CollatorStkPartialUnstakeSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }

    override func onViewDidLoad() {
        super.onViewDidLoad()

        setupHandlers()
    }

    override func onSetupLocalization() {
        super.onSetupLocalization()

        setupAmountInputAccessoryView()
    }
}

private extension CollatorStkPartialUnstakeSetupVC {
    private func setupAmountInputAccessoryView() {
        let accessoryView = UIFactory.default.createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        rootView.amountInputView.textField.inputAccessoryView = accessoryView
    }

    private func setupHandlers() {
        let amountChangeAction = UIAction { [weak self] _ in
            guard let self else {
                return
            }

            let amount = rootView.amountInputView.inputViewModel?.decimalAmount
            presenter?.updateAmount(amount)

            updateActionButtonState()
        }

        rootView.amountInputView.addAction(amountChangeAction, for: .editingChanged)
    }
}

extension CollatorStkPartialUnstakeSetupVC: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        rootView.amountInputView.textField.resignFirstResponder()

        presenter?.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        rootView.amountInputView.textField.resignFirstResponder()
    }
}

extension CollatorStkPartialUnstakeSetupVC: CollatorStkPartialUnstakeSetupViewProtocol {}
