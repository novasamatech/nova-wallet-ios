@testable import novawallet

// substrate-sdk-ios 5, Operation-iOS 3 and Foundation-iOS 1.5 export public types under names the app
// already uses for its own. Inside the app the module's declaration wins, but a test file imports both the
// app and the packages, so each of these names would be ambiguous there. The aliases below make the test
// targets resolve them to the app's types, which is what the tests have always exercised.

// MARK: Primitive aliases (the same underlying types on both sides)

typealias AccountAddress = novawallet.AccountAddress
typealias AccountId = novawallet.AccountId
typealias Balance = novawallet.Balance
typealias BlockHash = novawallet.BlockHash
typealias BlockHashData = novawallet.BlockHashData
typealias BlockNumber = novawallet.BlockNumber
typealias BlockTime = novawallet.BlockTime
typealias ExtrinsicHash = novawallet.ExtrinsicHash
typealias ExtrinsicIndex = novawallet.ExtrinsicIndex
typealias ParaId = novawallet.ParaId

// MARK: Runtime coding

typealias RuntimeCoderFactory = novawallet.RuntimeCoderFactory
typealias RuntimeCoderFactoryProtocol = novawallet.RuntimeCoderFactoryProtocol
typealias RuntimeCodingServiceProtocol = novawallet.RuntimeCodingServiceProtocol
typealias CallCodingPath = novawallet.CallCodingPath
typealias ConstantCodingPath = novawallet.ConstantCodingPath
typealias StorageCodingPath = novawallet.StorageCodingPath
typealias EventCodingPath = novawallet.EventCodingPath
typealias Event = novawallet.Event
typealias EventRecord = novawallet.EventRecord
typealias ExtrinsicExtraction = novawallet.ExtrinsicExtraction
typealias Substrate = novawallet.Substrate
typealias SystemPallet = novawallet.SystemPallet
typealias UtilityPallet = novawallet.UtilityPallet
typealias Block = novawallet.Block
typealias RuntimeDispatchInfo = novawallet.RuntimeDispatchInfo
typealias BigRational = novawallet.BigRational
typealias ChainAssetId = novawallet.ChainAssetId

// MARK: Storage and state calls

typealias ChainStorageItem = novawallet.ChainStorageItem
typealias StorageRequestFactory = novawallet.StorageRequestFactory
typealias StorageRequestFactoryProtocol = novawallet.StorageRequestFactoryProtocol
typealias StorageResponse<T: Decodable> = novawallet.StorageResponse<T>
typealias MapRemoteStorageRequest<T: Encodable> = novawallet.MapRemoteStorageRequest<T>
typealias UnkeyedRemoteStorageRequest = novawallet.UnkeyedRemoteStorageRequest
typealias MapKeyEncodingOperation<T: Encodable> = novawallet.MapKeyEncodingOperation<T>
typealias UnkeyedEncodingOperation = novawallet.UnkeyedEncodingOperation
typealias StorageKeyEncodingOperationError = novawallet.StorageKeyEncodingOperationError
typealias StorageDecodingOperation<T: Decodable> = novawallet.StorageDecodingOperation<T>
typealias StorageDecodingListOperation<T: Decodable> = novawallet.StorageDecodingListOperation<T>
typealias StorageFallbackDecodingOperation<T: Decodable> = novawallet.StorageFallbackDecodingOperation<T>
typealias StorageJSONDecodingOperation = novawallet.StorageJSONDecodingOperation
typealias StorageConstantOperation<T: Decodable> = novawallet.StorageConstantOperation<T>
typealias StorageDecodingOperationError = novawallet.StorageDecodingOperationError
typealias StateCallPath = novawallet.StateCallPath
typealias StateCallRpc = novawallet.StateCallRpc
typealias StateCallRequestFactory = novawallet.StateCallRequestFactory
typealias StateCallResultFromTypeNameDecoder<T: Decodable> = novawallet.StateCallResultFromTypeNameDecoder<T>

// MARK: Signing and extrinsics

typealias DummySigner = novawallet.DummySigner
typealias SignatureCreatorProtocol = novawallet.SignatureCreatorProtocol
typealias SigningWrapperProtocol = novawallet.SigningWrapperProtocol
typealias SigningWrapperFactoryProtocol = novawallet.SigningWrapperFactoryProtocol
typealias MetadataHashOperationFactory = novawallet.MetadataHashOperationFactory
typealias MetadataHashOperationFactoryProtocol = novawallet.MetadataHashOperationFactoryProtocol

// MARK: Operations and helpers

typealias OperationCombiningService<T> = novawallet.OperationCombiningService<T>
typealias Scheduler = novawallet.Scheduler
typealias SchedulerProtocol = novawallet.SchedulerProtocol
typealias SchedulerDelegate = novawallet.SchedulerDelegate
typealias Atomic<Value> = novawallet.Atomic<Value>
typealias WeakWrapper = novawallet.WeakWrapper
