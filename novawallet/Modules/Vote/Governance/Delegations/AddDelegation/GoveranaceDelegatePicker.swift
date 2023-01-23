final class GoveranaceDelegatePicker<Item>: ModalPickerViewControllerDelegate {
    let didSelectClosure: (Item?) -> Void
    let items: [Item]

    init(items: [Item], didSelectClosure: @escaping (Item?) -> Void) {
        self.items = items
        self.didSelectClosure = didSelectClosure
    }

    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        didSelectClosure(items[index])
    }

    func modalPickerDidCancel(context _: AnyObject?) {
        didSelectClosure(nil)
    }
}
