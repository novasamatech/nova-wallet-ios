enum DelegateVotedReferenda {
    case allTimes
    case recent(days: Int, fetchBlockTreshold: BlockNumber)
}
