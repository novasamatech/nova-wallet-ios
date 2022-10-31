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
                        TrackTestBuilding.Vote(referendum: 0, amount: 1, unlockAt: 1000)
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
                        TrackTestBuilding.Vote(referendum: 1, amount: 2, unlockAt: 1000)
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
                        TrackTestBuilding.Vote(referendum: 0, amount: 8, unlockAt: 1000)
                        TrackTestBuilding.Vote(referendum: 1, amount: 2, unlockAt: 1000)
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
                        TrackTestBuilding.Vote(referendum: 1, amount: 2, unlockAt: 1000)
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
                        TrackTestBuilding.Vote(referendum: 0, amount: 1, unlockAt: 1100)
                    }
                }
                TrackTestBuilding.track(1) {
                    TrackTestBuilding.VotingParams.locked(0)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 1, amount: 2, unlockAt: 1000)
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

    func testShouldIncludeShadowedAction() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1200) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(1) {
                    TrackTestBuilding.VotingParams.locked(0)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 1, amount: 1, unlockAt: 1000)
                    }
                }
                TrackTestBuilding.track(2) {
                    TrackTestBuilding.VotingParams.locked(0)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 2, amount: 2, unlockAt: 1100)
                    }
                }
                TrackTestBuilding.track(3) {
                    TrackTestBuilding.VotingParams.locked(0)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 3, amount: 1, unlockAt: 1200)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 2) {
                    GovernanceUnlockSchedule.Action.unvote(track: 2, index: 2)
                    GovernanceUnlockSchedule.Action.unlock(track: 2)
                    GovernanceUnlockSchedule.Action.unvote(track: 1, index: 1)
                    GovernanceUnlockSchedule.Action.unlock(track: 1)
                    GovernanceUnlockSchedule.Action.unvote(track: 3, index: 3)
                    GovernanceUnlockSchedule.Action.unlock(track: 3)
                }
            }
        }
    }

    func testShouldTakeGapIntoAccount() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.locked(10)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 0, amount: 2, unlockAt: 1000)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 10) {
                    GovernanceUnlockSchedule.Action.unvote(track: 0, index: 0)
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                }
            }
        }
    }

    func testGapShouldBeLimitedWithOtherLocks() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.locked(10)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 0, amount: 1, unlockAt: 1000)
                    }
                }

                TrackTestBuilding.track(1) {
                    TrackTestBuilding.VotingParams.prior(amount: 10, unlockAt: 1000)
                }

                TrackTestBuilding.track(2) {
                    TrackTestBuilding.VotingParams.prior(amount: 1, unlockAt: 1100)
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 9) {
                    GovernanceUnlockSchedule.Action.unvote(track: 0, index: 0)
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                    GovernanceUnlockSchedule.Action.unlock(track: 1)
                }

                UnlockScheduleTestBuilding.ScheduleResult.remainingItems {
                    UnlockScheduleTestBuilding.unlock(amount: 1, atBlock: 1100) {
                        GovernanceUnlockSchedule.Action.unlock(track: 2)
                    }
                }
            }
        }
    }

    func testGapClaimShouldBeDelayed() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.locked(10)
                }

                TrackTestBuilding.track(1) {
                    TrackTestBuilding.VotingParams.prior(amount: 10, unlockAt: 1100)
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.remainingItems {
                    UnlockScheduleTestBuilding.unlock(amount: 10, atBlock: 1100) {
                        GovernanceUnlockSchedule.Action.unlock(track: 0)
                        GovernanceUnlockSchedule.Action.unlock(track: 1)
                    }
                }
            }
        }
    }

    func testShouldNotDuplicateUnlockCommandWithBothPriorAndGapPresent() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1100) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.locked(10)
                    TrackTestBuilding.VotingParams.prior(amount: 5, unlockAt: 1050)
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 10) {
                    GovernanceUnlockSchedule.Action.unlock(track: 0)
                }
            }
        }
    }

    func testPendingShouldBeSortedByRemainingTime() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(0) {
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 0, amount: 3, unlockAt: 1100)
                        TrackTestBuilding.Vote(referendum: 2, amount: 2, unlockAt: 1200)
                        TrackTestBuilding.Vote(referendum: 1, amount: 1, unlockAt: 1300)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.remainingItems {
                    UnlockScheduleTestBuilding.unlock(amount: 1, atBlock: 1100) {
                        GovernanceUnlockSchedule.Action.unvote(track: 0, index: 0)
                        GovernanceUnlockSchedule.Action.unlock(track: 0)
                    }

                    UnlockScheduleTestBuilding.unlock(amount: 1, atBlock: 1200) {
                        GovernanceUnlockSchedule.Action.unvote(track: 0, index: 2)
                        GovernanceUnlockSchedule.Action.unlock(track: 0)
                    }

                    UnlockScheduleTestBuilding.unlock(amount: 1, atBlock: 1300) {
                        GovernanceUnlockSchedule.Action.unvote(track: 0, index: 1)
                        GovernanceUnlockSchedule.Action.unlock(track: 0)
                    }
                }
            }
        }
    }

    func testGapShouldNotBeCoveredByItsTrackLocks() {
        GovernanceUnlocksTestBuilding.run(atBlock: 1000) {
            GovernanceUnlocksTestBuilding.given {
                TrackTestBuilding.track(20) {
                    TrackTestBuilding.VotingParams.locked(1)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 13, amount: 1, unlockAt: 2000)
                    }
                }

                TrackTestBuilding.track(21) {
                    TrackTestBuilding.VotingParams.locked(101)
                    TrackTestBuilding.VotingParams.votes {
                        TrackTestBuilding.Vote(referendum: 5, amount: 10, unlockAt: 1500)
                    }
                }
            }

            GovernanceUnlocksTestBuilding.expect {
                UnlockScheduleTestBuilding.ScheduleResult.availableItem(amount: 91) {
                    GovernanceUnlockSchedule.Action.unlock(track: 21)
                }

                UnlockScheduleTestBuilding.ScheduleResult.remainingItems {
                    UnlockScheduleTestBuilding.unlock(amount: 9, atBlock: 1500) {
                        GovernanceUnlockSchedule.Action.unvote(track: 21, index: 5)
                        GovernanceUnlockSchedule.Action.unlock(track: 21)
                    }

                    UnlockScheduleTestBuilding.unlock(amount: 1, atBlock: 2000) {
                        GovernanceUnlockSchedule.Action.unvote(track: 20, index: 13)
                        GovernanceUnlockSchedule.Action.unlock(track: 20)
                    }
                }
            }
        }
    }
}
