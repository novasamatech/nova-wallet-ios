protocol StackCardViewTextProtocol: AnyObject {
    func setSummary(loadingState: LoadableViewModelState<String>)
    func setRequestedAmount(loadingState: LoadableViewModelState<BalanceViewModelProtocol?>)
}

protocol StackCardBackgroundProtocol: AnyObject {
    func setBackgroundGradient(model: GradientModel)
}

typealias StackCardViewUpdatable = StackCardViewTextProtocol & StackCardBackgroundProtocol
