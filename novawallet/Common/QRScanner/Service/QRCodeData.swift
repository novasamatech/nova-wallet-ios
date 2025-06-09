import Foundation

enum QRCodeData: Equatable {
    case plain(String)
    case raw(Data)
}
