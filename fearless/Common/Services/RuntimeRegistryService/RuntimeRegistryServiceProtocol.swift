import Foundation
import RobinHood
import SubstrateSdk

typealias RuntimeMetadataClosure = () throws -> RuntimeMetadata

protocol RuntimeRegistryServiceProtocol: ApplicationServiceProtocol {
    func update(to chain: Chain)
}
