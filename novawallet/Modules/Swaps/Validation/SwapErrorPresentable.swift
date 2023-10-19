import Foundation

protocol SwapErrorPresentable: BaseErrorPresentable {
}

extension SwapErrorPresentable where Self: AlertPresentable & ErrorPresentable {
}
