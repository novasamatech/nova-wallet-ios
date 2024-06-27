import Foundation

class OnboardingMainBaseWireframe {
    func presentSecretTypeSelection(
        from view: OnboardingMainViewProtocol?,
        handler: @escaping (SecretSource) -> Void
    ) {
        let options = SecretSource.displayOptions

        let closureHandler: (Int) -> Void = { index in
            handler(options[index])
        }

        guard let pickerView = ModalPickerFactory.createPickerListForSecretSource(
            options: options,
            delegate: self,
            context: ModalPickerClosureContext(handler: closureHandler)
        ) else {
            return
        }

        view?.controller.present(pickerView, animated: true, completion: nil)
    }
}

extension OnboardingMainBaseWireframe: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let closureContext = context as? ModalPickerClosureContext else {
            return
        }

        closureContext.process(selectedIndex: index)
    }
}
