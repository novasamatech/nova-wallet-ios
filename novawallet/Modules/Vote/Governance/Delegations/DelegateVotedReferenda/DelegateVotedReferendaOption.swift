enum DelegateVotedReferendaOption {
    case allTimes
    case recent(days: Int, fetchBlockTreshold: BlockNumber)
}
