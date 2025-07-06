import Foundation

protocol MultilineTextInputViewDelegate: AnyObject {
    func textInputViewWillStartEditing(_ inputView: MultilineTextInputView)
    func textInputViewShouldReturn(_ inputView: MultilineTextInputView) -> Bool
}
