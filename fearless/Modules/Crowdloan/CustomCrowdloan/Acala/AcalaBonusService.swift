import Foundation
import RobinHood
import BigInt
import IrohaCrypto
import FearlessUtils

final class AcalaBonusService {
    static let defaultReferralCode = "0xbcb330a49b5766dcd63fff92cf95243ec2a29c4131f19155724095e5cfd5197a"

    #if DEBUG
        static let baseURL = URL(string: "https://crowdloan.aca-dev.network")!
    #else
        static let baseURL = URL(string: "https://crowdloan.aca-api.network")!
    #endif

    static let apiReferral = "/referral"
    static let apiStatement = "/statement"
    static let apiContribute = "/contribute"

    var bonusRate: Decimal { 0.05 }
    var termsURL: URL { URL(string: "https://acala.network/karura/terms")! }
    private(set) var referralCode: String?

    let signingWrapper: SigningWrapperProtocol
    let address: AccountAddress
    let operationManager: OperationManagerProtocol
    let requestModifier: NetworkRequestModifierProtocol = AcalaRequestModifier()

    init(
        address: AccountAddress,
        signingWrapper: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.address = address
        self.signingWrapper = signingWrapper
        self.operationManager = operationManager
    }

    func createStatementFetchOperation() -> BaseOperation<String> {
        let url = Self.baseURL.appendingPathComponent(Self.apiStatement)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<String> { data in
            let resultData = try JSONDecoder().decode(
                KaruraStatementData.self,
                from: data
            )

            return resultData.statement
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }

    func createContributeOperation(
        dependingOn infoOperation: BaseOperation<KaruraVerifyInfo>
    ) -> BaseOperation<Void> {
        let url = Self.baseURL.appendingPathComponent(Self.apiContribute)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

            let info = try infoOperation.extractNoCancellableResultData()
            request.httpBody = try JSONEncoder().encode(info)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Void> { data in
            let resultData = try JSONDecoder().decode(
                KaruraResultData.self,
                from: data
            )

            guard resultData.result else {
                throw CrowdloanBonusServiceError.veficationFailed
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }
}

extension AcalaBonusService: CrowdloanBonusServiceProtocol {
    func save(referralCode: String, completion closure: @escaping (Result<Void, Error>) -> Void) {
        let url = Self.baseURL
            .appendingPathComponent(Self.apiReferral)
            .appendingPathComponent(referralCode)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(
                KaruraResultData.self,
                from: data
            )

            return resultData.result
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operation.extractNoCancellableResultData()

                    if result {
                        self?.referralCode = referralCode
                        closure(.success(()))
                    } else {
                        closure(.failure(CrowdloanBonusServiceError.invalidReferral))
                    }

                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .invalidParameters {
                        closure(.failure(CrowdloanBonusServiceError.invalidReferral))
                    } else {
                        closure(.failure(CrowdloanBonusServiceError.internalError))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func applyOffchainBonusForContribution(
        amount: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let referralCode = referralCode else {
            DispatchQueue.main.async {
                closure(.failure(CrowdloanBonusServiceError.veficationFailed))
            }

            return
        }

        let statementOperation = createStatementFetchOperation()

        let infoOperation = ClosureOperation<KaruraVerifyInfo> {
            guard
                let statement = try statementOperation.extractNoCancellableResultData().data(using: .utf8) else {
                throw CrowdloanBonusServiceError.veficationFailed
            }

            let signedData = try self.signingWrapper.sign(statement)

            return KaruraVerifyInfo(
                address: self.address,
                amount: String(amount),
                signature: signedData.rawData().toHex(includePrefix: true),
                referral: referralCode
            )
        }

        infoOperation.addDependency(statementOperation)

        let verifyOperation = createContributeOperation(dependingOn: infoOperation)
        verifyOperation.addDependency(infoOperation)

        verifyOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try verifyOperation.extractNoCancellableResultData()
                    closure(.success(()))
                } catch {
                    if let responseError = error as? NetworkResponseError, responseError == .invalidParameters {
                        closure(.failure(CrowdloanBonusServiceError.veficationFailed))
                    } else {
                        closure(.failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [statementOperation, infoOperation, verifyOperation], in: .transient)
    }

    func applyOnchainBonusForContribution(
        amount _: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        builder
    }
}

private class AcalaRequestModifier: NetworkRequestModifierProtocol {
    func modify(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.addValue(
            "Bearer \(AcalaKeys.authToken)",
            forHTTPHeaderField: "Authorization"
        )
        return modifiedRequest
    }
}
