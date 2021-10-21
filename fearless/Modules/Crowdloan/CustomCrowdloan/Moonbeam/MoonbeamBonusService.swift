import Foundation
import RobinHood
import BigInt
import IrohaCrypto
import FearlessUtils

final class MoonbeamBonusService {
    #if DEBUG
        static let baseURL = URL(string: "https://wallet-test.api.purestake.xyz")!
    #endif

    #if DEBUG
        static let apiKey = "4klO0S7XEI5I2eAkWLoSH6thDH5FuRbb6tpR7PqU"
    #endif

    static let apiHealth = "/health"

    let address: AccountAddress
    let operationManager: OperationManagerProtocol

    init(
        address: AccountAddress,
        operationManager: OperationManagerProtocol
    ) {
        self.address = address
        self.operationManager = operationManager
    }

    func createCheckHealthOperation() -> BaseOperation<Void> {
        let url = Self.baseURL.appendingPathComponent(Self.apiHealth)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            request.addValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Void> { _ in
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
