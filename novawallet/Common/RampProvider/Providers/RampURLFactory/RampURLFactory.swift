import Operation_iOS

protocol RampURLFactory {
    func createURLWrapper() -> CompoundOperationWrapper<URL>
}

enum RampURLFactoryError: Error {
    case invalidURLComponents
}
