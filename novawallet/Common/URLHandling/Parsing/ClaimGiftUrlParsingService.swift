import Foundation
import Operation_iOS
import NovaCrypto
import Foundation_iOS

final class ClaimGiftUrlParsingService {
    private let chainRegistry: ChainRegistryProtocol
    private let claimAvailabilityChecker: GiftClaimAvailabilityCheckFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        claimAvailabilityChecker: GiftClaimAvailabilityCheckFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.claimAvailabilityChecker = claimAvailabilityChecker
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension ClaimGiftUrlParsingService {
    func createWrapper(
        from payloadString: String
    ) -> CompoundOperationWrapper<GiftClaimNavigation> {
        let infoWrapper = createParsePayloadWrapper(string: payloadString)
        let checkWrapper = createGiftClaimCheckWrapper(dependingOn: infoWrapper)

        let resultOperation = ClosureOperation {
            let checkResult = try checkWrapper.targetOperation.extractNoCancellableResultData()

            switch checkResult.availability {
            case let .claimable(totalAmount):
                return GiftClaimNavigation(
                    info: checkResult.claimableGiftInfo,
                    totalAmount: totalAmount
                )
            case .claimed:
                throw OpenScreenUrlParsingError.openGiftClaimScreen(.alreadyClaimed)
            }
        }

        checkWrapper.addDependency(wrapper: infoWrapper)
        resultOperation.addDependency(checkWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: infoWrapper.allOperations + checkWrapper.allOperations
        )
    }

    func createParsePayloadWrapper(string: String) -> CompoundOperationWrapper<ClaimableGiftInfo> {
        let rawPayloadComponents = string.split(by: .underscore)

        guard rawPayloadComponents.count == 3 else {
            return .createWithError(OpenScreenUrlParsingError.openGiftClaimScreen(.invalidURL))
        }

        let seed = rawPayloadComponents[0]
        let shortChainId = rawPayloadComponents[1]
        let assetSymbol = rawPayloadComponents[2]

        let chainWrapper = chainRegistry.asyncWaitChainForeverWrapper { chainModel in
            let shortChainIdMaxLength = 6
            let chainId = chainModel.chainId.split(by: .colon).last ?? ""

            let endIndex: String.Index = chainId.count < shortChainIdMaxLength
                ? chainId.endIndex
                : chainId.index(chainId.startIndex, offsetBy: shortChainIdMaxLength)

            return chainId[chainId.startIndex ..< endIndex] == shortChainId
        }

        let mapOperation = ClosureOperation {
            let chainId = try chainWrapper.targetOperation.extractNoCancellableResultData()?.chainId

            guard let chainId else {
                throw OpenScreenUrlParsingError.openGiftClaimScreen(.chainNotFound)
            }

            return ClaimableGiftInfo(
                seed: try Data(hexString: seed),
                chainId: chainId,
                assetSymbol: assetSymbol
            )
        }

        mapOperation.addDependency(chainWrapper.targetOperation)

        return chainWrapper.insertingTail(operation: mapOperation)
    }

    func createGiftClaimCheckWrapper(
        dependingOn infoWrapper: CompoundOperationWrapper<ClaimableGiftInfo>
    ) -> CompoundOperationWrapper<GiftClaimAvailabilityCheckResult> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let info = try infoWrapper.targetOperation.extractNoCancellableResultData()

            return self.claimAvailabilityChecker.createAvailabilityWrapper(for: info)
        }
    }
}

// MARK: - OpenScreenUrlParsingServiceProtocol

extension ClaimGiftUrlParsingService: OpenScreenUrlParsingServiceProtocol {
    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    ) {
        guard
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = urlComponents.queryItems
        else {
            completion(.failure(.openGiftClaimScreen(.invalidURL)))
            return
        }

        let payloadString: String? = queryItems.first {
            $0.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) == UniversalLink.Gift.QueryKey.payload
        }?.value

        guard let payloadString else {
            completion(.failure(.openGiftClaimScreen(.invalidURL)))
            return
        }

        let wrapper = createWrapper(from: payloadString)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case let .success(navigation):
                completion(.success(.giftClaim(navigation)))
            case let .failure(error):
                guard case let OpenScreenUrlParsingError.openGiftClaimScreen(serviceError) = error else {
                    completion(.failure(.openGiftClaimScreen(.invalidURL)))
                    return
                }

                completion(.failure(.openGiftClaimScreen(serviceError)))
            }
        }
    }

    func cancel() {}
}
