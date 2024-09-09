protocol StackCardViewTextProtocol: AnyObject {
    func setSummary(loadingState: LoadableViewModelState<String>)
    func setRequestedAmount(loadingState: LoadableViewModelState<VoteCardViewModel.RequestedAmount?>)
}

protocol StackCardBackgroundProtocol: AnyObject {
    func setBackgroundGradient(model: GradientModel)
}

typealias StackCardViewUpdatable = StackCardViewTextProtocol & StackCardBackgroundProtocol
