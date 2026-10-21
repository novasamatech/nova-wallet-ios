import Foundation

struct MercuryoGenericResponse<R: Decodable>: Decodable {
    let status: Int
    let data: R?
}
