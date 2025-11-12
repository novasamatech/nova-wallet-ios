import Foundation
import Operation_iOS
import NovaCrypto
import Foundation_iOS

final class ClaimGiftUrlParsingService {
    private let chainRegistry: ChainRegistryProtocol
    private let claimAvailabilityChecker: GiftClaimAvailabilityCheckFactoryProtocol
    private let giftPublicKeyProvider: GiftPublicKeyProvidingProtocol
    private let payloadParser: GiftLinkPayloadParserProtocol
    private let operationQueue: OperationQueue

    let callStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        claimAvailabilityChecker: GiftClaimAvailabilityCheckFactoryProtocol,
        giftPublicKeyProvider: GiftPublicKeyProvidingProtocol,
        payloadParser: GiftLinkPayloadParserProtocol = GiftLinkPayloadParser(),
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.claimAvailabilityChecker = claimAvailabilityChecker
        self.giftPublicKeyProvider = giftPublicKeyProvider
        self.payloadParser = payloadParser
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension ClaimGiftUrlParsingService {
    func createWrapper(
        from payloadString: String
    ) -> CompoundOperationWrapper<GiftClaimNavigation> {
        let claimableGiftWrapper = createParsePayloadWrapper(string: payloadString)
        let checkWrapper = createGiftClaimCheckWrapper(dependingOn: claimableGiftWrapper)

        let resultOperation = ClosureOperation {
            let claimableGift = try claimableGiftWrapper.targetOperation.extractNoCancellableResultData()
            let checkResult = try checkWrapper.targetOperation.extractNoCancellableResultData()

            switch checkResult.availability {
            case let .claimable(totalAmount):
                return GiftClaimNavigation(
                    claimableGiftPayload: claimableGift.info(),
                    totalAmount: totalAmount
                )
            case .claimed:
                throw OpenScreenUrlParsingError.openGiftClaimScreen(.alreadyClaimed)
            }
        }

        checkWrapper.addDependency(wrapper: claimableGiftWrapper)
        resultOperation.addDependency(checkWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: claimableGiftWrapper.allOperations + checkWrapper.allOperations
        )
    }

    func createParsePayloadWrapper(string: String) -> CompoundOperationWrapper<ClaimableGift> {
        guard let payload = payloadParser.parseLinkPayload(payloadString: string) else {
            return .createWithError(OpenScreenUrlParsingError.openGiftClaimScreen(.invalidURL))
        }

        let chainWrapper = chainRegistry.asyncWaitChainForeverWrapper { chainModel in
            let shortChainIdMaxLength = 6
            let chainId = chainModel.chainId.split(by: .colon).last ?? ""

            let endIndex: String.Index = chainId.count < shortChainIdMaxLength
                ? chainId.endIndex
                : chainId.index(chainId.startIndex, offsetBy: shortChainIdMaxLength)

            return chainId[chainId.startIndex ..< endIndex] == payload.chainId
        }

        let mapOperation = ClosureOperation {
            let chain = try chainWrapper.targetOperation.extractNoCancellableResultData()
            let seed = try Data(hexString: payload.seed)

            guard let chain, let chainAsset = chain.chainAssetForSymbol(payload.assetSymbol) else {
                throw OpenScreenUrlParsingError.openGiftClaimScreen(.chainNotFound)
            }

            let publicKeyFetchRequest = GiftPublicKeyFetchRequest(
                seed: seed,
                ethereumBased: chain.isEthereumBased
            )
            let publicKey: Data = try self.giftPublicKeyProvider.getPublicKey(
                request: publicKeyFetchRequest
            )
            let accountId = try chain.isEthereumBased
                ? publicKey.ethereumAddressFromPublicKey()
                : publicKey.publicKeyToAccountId()

            return ClaimableGift(
                seed: seed,
                accountId: accountId,
                chainAsset: chainAsset
            )
        }

        mapOperation.addDependency(chainWrapper.targetOperation)

        return chainWrapper.insertingTail(operation: mapOperation)
    }

    func createGiftClaimCheckWrapper(
        dependingOn claimableGiftWrapper: CompoundOperationWrapper<ClaimableGift>
    ) -> CompoundOperationWrapper<GiftClaimAvailabilityCheckResult> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let claimableGift = try claimableGiftWrapper.targetOperation.extractNoCancellableResultData()

            return self.claimAvailabilityChecker.createAvailabilityWrapper(for: claimableGift)
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

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
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

    func cancel() {
        callStore.cancel()
    }
}

struct ClaimGiftPayload: Codable {
    let seed: Data
    let accountId: AccountId
    let chainAssetId: ChainAssetId
}
