import Foundation

protocol TextInputViewDelegate: AnyObject {
    func textInputViewWillStartEditing(_ inputView: TextInputView)
    func textInputViewShouldReturn(_ inputView: TextInputView) -> Bool
}
