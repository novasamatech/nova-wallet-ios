import Foundation

class OnboardingMainBaseWireframe {}

extension OnboardingMainBaseWireframe: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let closureContext = context as? ModalPickerClosureContext else {
            return
        }

        closureContext.process(selectedIndex: index)
    }
}
