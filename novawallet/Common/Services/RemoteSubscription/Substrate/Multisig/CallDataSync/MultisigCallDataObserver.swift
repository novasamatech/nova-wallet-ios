import Foundation
import SubstrateSdk

protocol MultisigCallDataObserver: AnyObject {
    func didReceive(newCallData: [Multisig.PendingOperation.Key: MultisigCallOrHash])
}
