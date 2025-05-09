import Foundation
import Operation_iOS

enum RaiseCardsProviderSourceError: Error {
    case unsupported
}

final class RaiseCardsProviderSource {
    typealias Model = RaiseCardLocal

    let operationFactory: RaiseOperationFactoryProtocol

    init(operationFactory: RaiseOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension RaiseCardsProviderSource: DataProviderSourceProtocol {
    func fetchOperation(by _: String) -> CompoundOperationWrapper<Model?> {
        CompoundOperationWrapper.createWithError(RaiseCardsProviderSourceError.unsupported)
    }

    func fetchOperation(page index: UInt) -> CompoundOperationWrapper<[Model]> {
        guard index == 0 else {
            return CompoundOperationWrapper.createWithError(RaiseCardsProviderSourceError.unsupported)
        }

        let cardsWrapper = operationFactory.createCardsWrapper()
        let mappingOperation = ClosureOperation<[Model]> {
            let response = try cardsWrapper.targetOperation.extractNoCancellableResultData()

            let brandDic = response.included?.reduce(into: [String: RaiseResponseContent<RaiseBrandAttributes>]()) {
                $0[$1.identifier] = $1
            }

            return response.data.enumerated().map { offset, card in
                let brand = brandDic?[card.attributes.brandId]

                return RaiseCardLocal(
                    fromRemote: card,
                    brand: brand?.attributes,
                    sortOrder: offset
                )
            }
        }

        mappingOperation.addDependency(cardsWrapper.targetOperation)

        return cardsWrapper.insertingTail(operation: mappingOperation)
    }
}
