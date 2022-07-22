import Foundation

protocol AccountInputViewDelegate: AnyObject {
    func accountInputViewWillStartEditing(_ inputView: AccountInputView)
    func accountInputViewShouldReturn(_ inputView: AccountInputView) -> Bool
}
