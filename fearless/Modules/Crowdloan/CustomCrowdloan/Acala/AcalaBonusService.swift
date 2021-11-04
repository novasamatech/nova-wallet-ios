import Foundation
import RobinHood
import BigInt
import IrohaCrypto
import SubstrateSdk

final class AcalaBonusService {
    #if F_RELEASE
        static let defaultReferralCode = "0xc5c184f0565e2192d6aedae584ee736cef875f0e1c558ee3ede26869acd0b4d6"
        static let baseURL = URL(string: "https://crowdloan.aca-api.network")!
    #else
        static let defaultReferralCode = "0x08eb319467ea54784cd9edfbd03bbcc53f7a021ed8d9ed2ca97b6ae46b3f6014"
        static let baseURL = URL(string: "https://crowdloan.aca-dev.network")!
    #endif

    static let apiReferral = "/referral"
    static let apiStatement = "/statement"
    static let apiContribute = "/contribute"
    static let apiTransfer = "/transfer"

    var selectedContributionMethod = AcalaContributionMethod.direct

    var bonusRate: Decimal { 0.05 }
    var termsURL: URL { URL(string: "https://acala.network/acala/terms")! }
    private(set) var referralCode: String?
    private var statementData: AcalaStatementData?

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

    func createStatementFetchOperation() -> BaseOperation<AcalaStatementData> {
        let url = Self.baseURL.appendingPathComponent(Self.apiStatement)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<AcalaStatementData> { data in
            let resultData = try JSONDecoder().decode(
                AcalaStatementData.self,
                from: data
            )

            return resultData
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

    private func createTransferOperation(
        info: AcalaTransferInfo
    ) -> BaseOperation<Void> {
        let url = Self.baseURL.appendingPathComponent(Self.apiTransfer)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            request.setValue(HttpContentType.json.rawValue, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
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
        switch selectedContributionMethod {
        case .direct:
            applyOffchainBonusForContributionDirect(amount: amount, with: closure)
        case .liquid:
            applyOffchainBonusForContributionLiquid(amount: amount, with: closure)
        }
    }

    private func applyOffchainBonusForContributionDirect(
        amount: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        let statementOperation = createStatementFetchOperation()

        let infoOperation = ClosureOperation<KaruraVerifyInfo> {
            guard
                let statement = try statementOperation.extractNoCancellableResultData().statement.data(using: .utf8) else {
                throw CrowdloanBonusServiceError.veficationFailed
            }

            let signedData = try self.signingWrapper.sign(statement)

            return KaruraVerifyInfo(
                address: self.address,
                amount: String(amount),
                signature: signedData.rawData().toHex(includePrefix: true),
                referral: self.referralCode
            )
        }

        infoOperation.addDependency(statementOperation)

        let contributeOperation = createContributeOperation(dependingOn: infoOperation)
        contributeOperation.addDependency(infoOperation)

        contributeOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try contributeOperation.extractNoCancellableResultData()
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

        operationManager.enqueue(operations: [statementOperation, infoOperation, contributeOperation], in: .transient)
    }

    private func applyOffchainBonusForContributionLiquid(
        amount: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        let statementOperation = createStatementFetchOperation()
        statementOperation.completionBlock = {
            do {
                let statement = try statementOperation.extractNoCancellableResultData()
                self.statementData = statement
            } catch {
                closure(.failure(error))
            }
        }

        let info = AcalaTransferInfo(
            address: address,
            amount: String(amount),
            referral: referralCode
        )
        let transferOperation = createTransferOperation(info: info)
        transferOperation.addDependency(statementOperation)

        transferOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    _ = try transferOperation.extractNoCancellableResultData()
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

        operationManager.enqueue(operations: [transferOperation, statementOperation], in: .transient)
    }

    func applyOnchainBonusForContribution(
        amount: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard
            selectedContributionMethod == .liquid,
            let statementData = statementData,
            let accountId = try? statementData.proxyAddress.toAccountId(),
            let statement = statementData.statement.data(using: .utf8)
        else {
            return builder
        }
        let builder = builder.reset()
        let callFactory = SubstrateCallFactory()
        let transferCall = callFactory.transfer(to: accountId, amount: amount)
        let statementRemark = callFactory.remarkWithEvent(remark: statement)

        if
            let referral = referralCode,
            let referralData = "referrer:\(referral)".data(using: .utf8) {
            let referralRemark = callFactory.remarkWithEvent(remark: referralData)
            return try builder
                .adding(call: transferCall)
                .adding(call: statementRemark)
                .adding(call: referralRemark)
        } else {
            return try builder
                .adding(call: transferCall)
                .adding(call: statementRemark)
        }
    }
}

private class AcalaRequestModifier: NetworkRequestModifierProtocol {
    func modify(request: URLRequest) throws -> URLRequest {
        let token = AcalaKeys.authToken
        var modifiedRequest = request
        modifiedRequest.addValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        return modifiedRequest
    }
}
