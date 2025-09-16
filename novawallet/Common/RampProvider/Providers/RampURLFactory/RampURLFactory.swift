import Operation_iOS
import Foundation

protocol RampURLFactory {
    func createURLWrapper() -> CompoundOperationWrapper<URL>
}

enum RampURLFactoryError: Error {
    case invalidURLComponents
}
