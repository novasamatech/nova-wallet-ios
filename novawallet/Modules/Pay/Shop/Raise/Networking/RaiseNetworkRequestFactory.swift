import Foundation
import Operation_iOS

typealias RaiseAuthTokenClosure = () throws -> RaiseAuthToken
typealias RaiseRetriableRequestClosure = (@escaping RaiseAuthTokenClosure) -> NetworkRequestFactoryProtocol
