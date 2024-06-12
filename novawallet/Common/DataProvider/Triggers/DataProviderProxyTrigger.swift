import Foundation
import Operation_iOS

final class DataProviderProxyTrigger: DataProviderTriggerProtocol {
    weak var delegate: DataProviderTriggerDelegate?

    func receive(event _: DataProviderEvent) {}
}
