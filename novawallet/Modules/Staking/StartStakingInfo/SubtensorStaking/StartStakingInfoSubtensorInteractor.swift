import Foundation
import Operation_iOS

/// v1 Subtensor interactor for Nova's generic StartStakingInfoViewController.
///
/// Inherits all the wallet / balance / price / staking-state subscription
/// behavior from StartStakingInfoBaseInteractor — that pipeline is chain
/// agnostic and fires the base presenter's didReceive(wallet:, price:,
/// assetBalance:) callbacks so the balance button on the info screen
/// populates normally.
///
/// Subtensor does not (yet) need any chain-specific subscription beyond
/// the base set — real on-chain stake queries are deferred to the post-MVP
/// integration pass.
final class StartStakingInfoSubtensorInteractor: StartStakingInfoBaseInteractor {}
