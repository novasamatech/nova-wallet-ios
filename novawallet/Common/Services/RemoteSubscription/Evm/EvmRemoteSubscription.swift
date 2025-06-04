import Foundation

protocol EvmRemoteSubscriptionProtocol {
    func start() throws

    func stop() throws
}
