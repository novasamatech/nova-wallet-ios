import Foundation
import Kingfisher
import Operation_iOS

protocol QRCodeWithLogoFactoryProtocol {
    func createQRCode(
        with payload: Data,
        logoInfo: ChainLogoImageInfo?,
        qrSize: CGSize,
        partialResultClosure: @escaping (Result<QRCodeWithLogoFactory.QRCreationResult, Error>) -> Void,
        completion: @escaping (Result<QRCodeWithLogoFactory.QRCreationResult, Error>) -> Void
    )
}

final class QRCodeWithLogoFactory {
    enum QRCreationResult: Equatable {
        case full(UIImage)
        case noLogo(UIImage)

        var image: UIImage {
            switch self {
            case let .full(image), let .noLogo(image):
                return image
            }
        }
    }

    let iconRetrievingFactory: ImageRetrieveOperationFactory<ChainLogoImageInfo>
    let operationQueue: OperationQueue
    let callbackQueue: DispatchQueue
    let logger: LoggerProtocol

    init(
        iconRetrievingFactory: ImageRetrieveOperationFactory<ChainLogoImageInfo>,
        operationQueue: OperationQueue,
        callbackQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.iconRetrievingFactory = iconRetrievingFactory
        self.operationQueue = operationQueue
        self.callbackQueue = callbackQueue
        self.logger = logger
    }
}

// MARK: QRCodeFactoryProtocol

extension QRCodeWithLogoFactory: QRCodeWithLogoFactoryProtocol {
    func createQRCode(
        with payload: Data,
        logoInfo: ChainLogoImageInfo?,
        qrSize: CGSize,
        partialResultClosure: @escaping (Result<QRCreationResult, Error>) -> Void,
        completion: @escaping (Result<QRCreationResult, Error>) -> Void
    ) {
        let wrapper = createQRWrapper(
            with: payload,
            logoInfo: logoInfo,
            qrSize: qrSize,
            partialResultClosure: partialResultClosure
        )

        novawallet.execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: callbackQueue,
            callbackClosure: completion
        )
    }
}

// MARK: Private

private extension QRCodeWithLogoFactory {
    struct QRWrapperResult {
        let wrapper: CompoundOperationWrapper<QRCreationResult>
        let remoteLogo: Bool
    }

    func checkCacheOperation(using logoInfo: ChainLogoImageInfo?) -> BaseOperation<Bool> {
        if let cacheKey = logoInfo?.type?.cacheKey {
            iconRetrievingFactory.checkCacheOperation(using: cacheKey)
        } else {
            .createWithResult(false)
        }
    }

    func createQRWrapper(
        with payload: Data,
        logoInfo: ChainLogoImageInfo?,
        qrSize: CGSize,
        partialResultClosure: @escaping (Result<QRCreationResult, Error>) -> Void
    ) -> CompoundOperationWrapper<QRCreationResult> {
        let checkCacheOperation = checkCacheOperation(using: logoInfo)

        let wrapper: CompoundOperationWrapper<QRCreationResult> = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self, let logoInfo else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            let cached = try checkCacheOperation.extractNoCancellableResultData()
            let usesCache: Bool = logoInfo.type?.cacheKey != nil

            return if !cached, usesCache {
                createDownloadLogoQRWrapper(
                    payload: payload,
                    logoInfo: logoInfo,
                    qrSize: qrSize,
                    partialResultClosure: partialResultClosure
                )
            } else if let cacheKey = logoInfo.type?.cacheKey {
                createCachedLogoQRWrapper(
                    cacheKey: cacheKey,
                    payload: payload,
                    logoInfo: logoInfo,
                    qrSize: qrSize
                )
            } else if let image = logoInfo.type?.image {
                createQRResultWrapper(
                    using: .createWithResult(image),
                    payload: payload,
                    logoInfo: logoInfo,
                    qrSize: qrSize
                )
            } else {
                createQRResultWrapper(
                    using: nil,
                    payload: payload,
                    logoInfo: logoInfo,
                    qrSize: qrSize
                )
            }
        }

        let dependencies = [checkCacheOperation].compactMap { $0 }

        wrapper.addDependency(operations: dependencies)

        return wrapper.insertingHead(operations: dependencies)
    }

    func createDownloadLogoQRWrapper(
        payload: Data,
        logoInfo: ChainLogoImageInfo,
        qrSize: CGSize,
        partialResultClosure: @escaping (Result<QRCreationResult, Error>) -> Void
    ) -> CompoundOperationWrapper<QRCreationResult> {
        let logoOperation = iconRetrievingFactory.downloadImageOperation(using: logoInfo)

        let partialQRWrapper = createQRResultWrapper(
            using: nil,
            payload: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )

        partialQRWrapper.targetOperation.completionBlock = { [weak self] in
            guard let self else { return }

            dispatchInQueueWhenPossible(callbackQueue) {
                do {
                    let value = try partialQRWrapper.targetOperation.extractNoCancellableResultData()
                    partialResultClosure(.success(value))
                } catch {
                    partialResultClosure(.failure(error))
                }
            }
        }

        let completeQRWrapper = createQRResultWrapper(
            using: logoOperation,
            payload: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )

        completeQRWrapper.targetOperation.addDependency(partialQRWrapper.targetOperation)

        return completeQRWrapper.insertingHead(operations: partialQRWrapper.allOperations)
    }

    func createCachedLogoQRWrapper(
        cacheKey: String,
        payload: Data,
        logoInfo: ChainLogoImageInfo,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<QRCreationResult> {
        let logoOperation = iconRetrievingFactory.retrieveImageOperation(using: cacheKey)

        return createQRResultWrapper(
            using: logoOperation,
            payload: payload,
            logoInfo: logoInfo,
            qrSize: qrSize
        )
    }

    func createQRResultWrapper(
        using logoOperation: BaseOperation<UIImage>?,
        payload: Data,
        logoInfo: ChainLogoImageInfo,
        qrSize: CGSize
    ) -> CompoundOperationWrapper<QRCreationResult> {
        var qrImageWrapper: CompoundOperationWrapper<UIImage>
        qrImageWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                return .createWithError(BaseOperationError.parentOperationCancelled)
            }

            var updatedLogoInfo: ChainLogoImageInfo? = logoInfo

            if let logoOperation {
                do {
                    let logoImage = try logoOperation.extractNoCancellableResultData()
                    updatedLogoInfo = logoInfo.byChangingToLocal(logoImage)
                } catch {
                    logger.error(error.localizedDescription)
                }
            } else {
                updatedLogoInfo = updatedLogoInfo?.withNoLogo()
            }

            let qrCodeOperation = QRWithLogoCreationOperation(
                payload: payload,
                qrSize: qrSize,
                logoInfo: updatedLogoInfo
            )

            return CompoundOperationWrapper(targetOperation: qrCodeOperation)
        }

        if let logoOperation {
            qrImageWrapper.addDependency(operations: [logoOperation])
            qrImageWrapper = qrImageWrapper.insertingHead(operations: [logoOperation])
        }

        let resultMappingOperation = ClosureOperation {
            let qrImage = try qrImageWrapper.targetOperation.extractNoCancellableResultData()

            let result: QRCreationResult = if logoOperation != nil {
                .full(qrImage)
            } else {
                .noLogo(qrImage)
            }

            return result
        }

        resultMappingOperation.addDependency(qrImageWrapper.targetOperation)

        return qrImageWrapper.insertingTail(operation: resultMappingOperation)
    }
}
