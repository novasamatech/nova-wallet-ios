import Foundation

protocol RampMessageHandling {
    func canHandleMessageOf(name: String) -> Bool
    func handle(message: Any, of name: String)
}
