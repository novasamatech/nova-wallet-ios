import Foundation
import SubstrateSdk

protocol ConnectionStateReporting {
    var state: WebSocketEngine.State { get }
}
