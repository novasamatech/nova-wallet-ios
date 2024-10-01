protocol CardStackable: AnyObject {
    func didBecomeTopView()
    func didAddToStack()
    func didPopFromStack(direction: CardsZStack.DismissalDirection)
    func didPredict(vote: VoteResult)
    func prepareForReuse()
}
