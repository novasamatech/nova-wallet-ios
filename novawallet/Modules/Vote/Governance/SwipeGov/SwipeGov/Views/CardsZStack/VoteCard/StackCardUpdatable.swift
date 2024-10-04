import Foundation

protocol StackCardViewTextProtocol: AnyObject {
    func setSummary(loadingState: LoadableViewModelState<NSAttributedString>)
    func setRequestedAmount(loadingState: LoadableViewModelState<BalanceViewModelProtocol?>)
}

protocol StackCardBackgroundProtocol: AnyObject {
    func setBackgroundGradient(model: GradientModel)
}

typealias StackCardViewUpdatable = StackCardViewTextProtocol & StackCardBackgroundProtocol
