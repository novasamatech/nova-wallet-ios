import Foundation

struct QRScannerViewSettings {
    let canUploadFromGallery: Bool
    let extendsUnderSafeArea: Bool

    init(canUploadFromGallery: Bool = true, extendsUnderSafeArea: Bool = false) {
        self.canUploadFromGallery = canUploadFromGallery
        self.extendsUnderSafeArea = extendsUnderSafeArea
    }
}
