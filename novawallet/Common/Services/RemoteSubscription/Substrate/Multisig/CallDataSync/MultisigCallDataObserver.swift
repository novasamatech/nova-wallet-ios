import Foundation
import SubstrateSdk

protocol MultisigCallDataObserver: AnyObject {
    func didReceive(newCallData: [CallDataKey: JSON])
}
