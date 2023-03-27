import Foundation

extension TextInputView {
    var isEmpty: Bool {
        (textField.text ?? "").isEmpty
    }
}

extension Array where Element == TextInputView {
    var anyEmpty: Bool {
        contains { $0.isEmpty }
    }
}
