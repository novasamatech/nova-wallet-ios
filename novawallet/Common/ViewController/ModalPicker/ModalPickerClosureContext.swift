import Foundation

final class ModalPickerClosureContext {
    let handler: (Int) -> Void

    init(handler: @escaping (Int) -> Void) {
        self.handler = handler
    }

    func process(selectedIndex: Int) {
        handler(selectedIndex)
    }
}
