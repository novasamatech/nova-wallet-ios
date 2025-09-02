import Foundation

protocol PayCardMessageHandling {
    func canHandleMessageOf(name: String) -> Bool
    func handle(message: Any, of name: String)
}
