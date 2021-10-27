import Foundation
import RobinHood
import BigInt
import IrohaCrypto
import FearlessUtils

protocol MoonbeamBonusServiceProtocol: CrowdloanBonusServiceProtocol {
    var hasMoonbeamAccount: Bool { get }
    func createCheckHealthOperation() -> BaseOperation<Void>
    func createCheckTermsOperation() -> BaseOperation<Bool>
    func createStatementFetchOperation() -> BaseOperation<Data>
    func createAgreeRemarkOperation(
        dependingOn statementOperation: BaseOperation<Data>
    ) -> BaseOperation<String>

    func createVerifyRemarkOperation(
        blockHash: String,
        extrinsicHash: String
    ) -> BaseOperation<Bool>
}

final class MoonbeamBonusService: MoonbeamBonusServiceProtocol {
    var bonusRate: Decimal = 0

    var termsURL: URL {
        URL(string: "https://github.com/moonbeam-foundation/crowdloan-self-attestation/tree/main/moonbeam")!
    }

    var referralCode: String? { nil }

    #if DEBUG
        static let baseURL = URL(string: "https://wallet-test.api.purestake.xyz")!
    #endif

    static let apiHealth = "/health"
    static func apiCheckRemark(address: AccountAddress) -> String {
        "/check-remark/\(address)"
    }

    static let agreeRemark = "/agree-remark"
    static let verifyRemark = "/verify-remark"
    static let makeSignature = "/make-signature"
    static let statementURL = URL(string: "https://raw.githubusercontent.com/moonbeam-foundation/crowdloan-self-attestation/main/moonbeam/README.md")!

    let paraId: ParaId
    let address: AccountAddress
    let etheriumAddress: AccountAddress?
    let signingWrapper: SigningWrapperProtocol
    let operationManager: OperationManagerProtocol
    private let requestModifier = MoonbeamRequestModifier()

    var hasMoonbeamAccount: Bool {
        etheriumAddress != nil
    }

    init(
        paraId: ParaId,
        address: AccountAddress,
        etheriumAddress: AccountAddress?,
        signingWrapper: SigningWrapperProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.paraId = paraId
        self.address = address
        self.etheriumAddress = etheriumAddress
        self.signingWrapper = signingWrapper
        self.operationManager = operationManager
    }

    /// Health check may be used to verify the geo-fencing for a given user.
    /// Users in a barred country will receive a 403 error
    func createCheckHealthOperation() -> BaseOperation<Void> {
        let url = Self.baseURL.appendingPathComponent(Self.apiHealth)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Void> { _ in
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }

    /// Ask PureStake if the address has submitted the attestation successfully.
    func createCheckTermsOperation() -> BaseOperation<Bool> {
        let url = Self.baseURL.appendingPathComponent(Self.apiCheckRemark(address: address))

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(
                MoonbeamVerifiedResponse.self,
                from: data
            )
            return resultData.verified
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }

    func createStatementFetchOperation() -> BaseOperation<Data> {
        let url = Self.statementURL
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Data> { data in
            data
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    /// Generate the content needed for the remark extrinsic.
    /// `signedMessage` needs to be a raw signed message
    /// by the address’ private key of the SHA-256 hash of the attestation
    func createAgreeRemarkOperation(
        dependingOn statementOperation: BaseOperation<Data>
    ) -> BaseOperation<String> {
        let url = Self.baseURL.appendingPathComponent(Self.agreeRemark)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue

            let statementRawData = try statementOperation.extractNoCancellableResultData()
            let statementData = statementRawData.sha256().toHex().data(using: .utf8)!
            let signedData = try self.signingWrapper.sign(statementData)
            let signedMessage = signedData.rawData().toHex()

            let remarkRequest = MoonbeamAgreeRemarkRequest(address: self.address, signedMessage: signedMessage)
            let body = try JSONEncoder().encode(remarkRequest)
            request.httpBody = body
            return request
        }

        let resultFactory = AnyNetworkResultFactory<String> { data in
            let resultData = try JSONDecoder().decode(
                MoonbeamAgreeRemarkResponse.self,
                from: data
            )
            return resultData.remark
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }

    /// Submit proof of remark for a given address - block should be finalized before sending
    func createVerifyRemarkOperation(
        blockHash: String,
        extrinsicHash: String
    ) -> BaseOperation<Bool> {
        let url = Self.baseURL.appendingPathComponent(Self.verifyRemark)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            let remarkRequest = MoonbeamVerifyRemarkRequest(
                address: self.address,
                extrinsicHash: extrinsicHash,
                blockHash: blockHash
            )
            request.httpBody = try JSONEncoder().encode(remarkRequest)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Bool> { data in
            let resultData = try JSONDecoder().decode(
                MoonbeamVerifiedResponse.self,
                from: data
            )
            return resultData.verified
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }

    func createMakeSignatureOperation(
        previousTotalContribution: BigUInt,
        contribution: BigUInt
    ) -> BaseOperation<String> {
        let url = Self.baseURL.appendingPathComponent(Self.makeSignature)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.post.rawValue
            let remarkRequest = MoonbeamMakeSignatureRequest(
                address: self.address,
                previousTotalContribution: String(previousTotalContribution),
                contribution: String(contribution),
                guid: UUID().uuidString
            )
            request.httpBody = try JSONEncoder().encode(remarkRequest)
            return request
        }

        let resultFactory = AnyNetworkResultFactory<String> { data in
            let resultData = try JSONDecoder().decode(
                MoonbeamMakeSignatureResponse.self,
                from: data
            )
            return resultData.signature
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.requestModifier = requestModifier
        return operation
    }

    func save(referralCode _: String, completion _: @escaping (Result<Void, Error>) -> Void) {
        print("save(referralCode")
    }

    func applyOffchainBonusForContribution(
        amount _: BigUInt,
        with closure: @escaping (Result<Void, Error>) -> Void
    ) {
        closure(.success(()))
    }

    func applyOnchainBonusForContribution(
        amount _: BigUInt,
        using builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        guard let address = etheriumAddress, let memo = try? Data(hexString: address), memo.count <= 32 else {
            throw CrowdloanBonusServiceError.invalidReferral
        }

        let addMemo = SubstrateCallFactory().addMemo(to: paraId, memo: memo)

        return try builder.adding(call: addMemo)
    }

    func provideSignature(
        previousContribution: BigUInt,
        newContribution: BigUInt,
        closure: @escaping (Result<MultiSignature?, Error>) -> Void
    ) {
        let signatureOperation = createMakeSignatureOperation(
            previousTotalContribution: previousContribution,
            contribution: newContribution
        )

        signatureOperation.completionBlock = {
            do {
                let signatureString = try signatureOperation.extractNoCancellableResultData()
                let signatureData = try Data(hexString: signatureString)
                closure(.success(MultiSignature.sr25519(data: signatureData)))
            } catch {
                closure(.failure(error))
            }
        }

        operationManager.enqueue(operations: [signatureOperation], in: .transient)
    }
}

private class MoonbeamRequestModifier: NetworkRequestModifierProtocol {
    #if DEBUG
        static let apiKey = "4klO0S7XEI5I2eAkWLoSH6thDH5FuRbb6tpR7PqU"
    #endif

    func modify(request: URLRequest) throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.addValue(Self.apiKey, forHTTPHeaderField: "x-api-key")
        return modifiedRequest
    }
}
