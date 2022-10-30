import XCTest
@testable import novawallet

class Gov2UnlockScheduleTests: XCTestCase {

    func testShouldHandleEmpty() {
        GovernanceUnlocksTestBuilding.run(atBlock: 0) {
            GovernanceUnlocksTestBuilding.given {}
            GovernanceUnlocksTestBuilding.expect {}
        }
    }

    func testShouldHandleSingleClaimable() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 0, balance: 1, unlockAt: 1000)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 1) {
                    GovernanceUnlockSchedule.Action.unvote(track: 0, index: 0)
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                }
            }
        }
    }

    func testShouldHandleBothPassedAndNotPriors() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.prior(amount: 2, unlockAt: 1000)
                }

                TrackTestBuilding.track(1) {
                    TrackTestBuilding.VotingParams.prior(amount: 1, unlockAt: 1100)
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 1) {
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                }

                UnlockScheduleTestBuilding.ScheduleResult.remainingItems {
                    UnlockScheduleTestBuilding.unlock(amount: 1, atBlock: 1100) {
                        GovernanceUnlockSchedule.Action.unlock(track: 1)
                    }
                }
            }
        }
    }

    func testShouldExtendVotesWithPrior() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.prior(amount: 1, unlockAt: 1100)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 1, balance: 2, unlockAt: 1000)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.remainingItems {
                    UnlockScheduleTestBuilding.unlock(amount: 2, atBlock: 1100) {
                        GovernanceUnlockSchedule.Action.unvote(track: 0, index: 1)
                        GovernanceUnlockSchedule.Action.unlock(track: 0)
                    }
                }
            }
        }
    }

    func testShouldTakeMaxBetweenTwoLocksWithSameTime() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 0, balance: 8, unlockAt: 1000)
                        TrackTestBuilding.Vote(referendum: 1, balance: 2, unlockAt: 1000)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 8) {
                    GovernanceUnlockSchedule.Action.unvote(track: 0, index: 0)
                    GovernanceUnlockSchedule.Action.unvote(track: 0, index: 1)
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                }
            }
        }
    }

    func testShouldHandleRegiggedPrior() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1200) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.prior(amount: 1, unlockAt: 1100)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 1, balance: 2, unlockAt: 1000)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 2) {
                    GovernanceUnlockSchedule.Action.unvote(track: 0, index: 1)
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                }
            }
        }
    }

    func testShouldFoldSeveralClaimableToOne() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1100) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.locked(0)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 0, balance: 1, unlockAt: 1100)
                    }
                }
                TrackTestBuilding.track(1) {
                    TrackTestBuilding.VotingParams.locked(0)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 1, balance: 2, unlockAt: 1000)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 2) {
                    GovernanceUnlockSchedule.Action.unvote(track: 1, index: 1)
                    GovernanceUnlockSchedule.Action.unlock(track: 1)
                    GovernanceUnlockSchedule.Action.unvote(track: 0, index: 0)
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                }
            }
        }
    }
}
