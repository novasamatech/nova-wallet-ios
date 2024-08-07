import Foundation
import SubstrateSdk
import Operation_iOS

final class ScaleDecoderOperation<T: ScaleDecodable>: BaseOperation<T?> {
    var data: Data?

    override func performAsync(_ callback: @escaping (Result<T?, Error>) -> Void) throws {
        guard let data = data else {
            callback(.success(nil))
            return
        }

        do {
            let decoder = try ScaleDecoder(data: data)
            let item = try T(scaleDecoder: decoder)
            callback(.success(item))
        } catch {
            callback(.failure(error))
        }
    }
}
