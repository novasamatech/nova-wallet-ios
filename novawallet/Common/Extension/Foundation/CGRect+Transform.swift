import Foundation

extension CGRect {
    func aspectFilled(for targetSize: CGSize) -> CGRect {
        var drawingSize = CGSize(
            width: size.width,
            height: size.width * targetSize.height / targetSize.width
        )

        if drawingSize.height < size.height {
            drawingSize.height = size.height
            drawingSize.width = size.height * targetSize.width / targetSize.height
        }

        let origin = CGPoint(
            x: midX - drawingSize.width / 2,
            y: midY - drawingSize.height / 2
        )

        return CGRect(origin: origin, size: drawingSize)
    }

    func centered(for targetSize: CGSize) -> CGRect {
        let origin = CGPoint(
            x: midX - targetSize.width / 2,
            y: midY - targetSize.height / 2
        )

        return CGRect(origin: origin, size: targetSize)
    }
}
