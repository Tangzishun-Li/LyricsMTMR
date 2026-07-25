// ============================================================
// 归档来源: MTMR/SupportHelpers.swift
// 归档原因: 以下方法从未被项目中任何代码调用
// ============================================================

// --- trim(): 从未被调用（项目中用的是 trimmingCharacters） ---
extension String {
    func trim() -> String {
        return trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}

// --- rotateByDegreess(degrees:): 从未被调用 ---
extension NSImage {
    func rotateByDegreess(degrees: CGFloat) -> NSImage {
        var imageBounds = NSZeroRect; imageBounds.size = size
        let pathBounds = NSBezierPath(rect: imageBounds)
        var transform = NSAffineTransform()
        transform.rotate(byDegrees: degrees)
        pathBounds.transform(using: transform as AffineTransform)
        let rotatedBounds: NSRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y, size.width, size.height)
        let rotatedImage = NSImage(size: rotatedBounds.size)

        imageBounds.origin.x = NSMidX(rotatedBounds) - (NSWidth(imageBounds) / 2)
        imageBounds.origin.y = NSMidY(rotatedBounds) - (NSHeight(imageBounds) / 2)

        transform = NSAffineTransform()
        transform.translateX(by: +(NSWidth(rotatedBounds) / 2), yBy: +(NSHeight(rotatedBounds) / 2))
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -(NSWidth(rotatedBounds) / 2), yBy: -(NSHeight(rotatedBounds) / 2))
        rotatedImage.lockFocus()
        transform.concat()
        draw(in: imageBounds, from: NSZeroRect, operation: NSCompositingOperation.copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }
}
