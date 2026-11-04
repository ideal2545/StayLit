// Draws the menu bar template icons.
// Usage: swift Tools/Icons/generate-menu-bar-icons.swift <output folder>
// Copy Active*.png into ActiveIcon.imageset and Inactive*.png into InactiveIcon.imageset.
import AppKit
// Menu bar glyphs, 22x20 pt, black on transparent (template images).
func draw(active: Bool, scale: CGFloat, to path: String) {
    let w = 22 * scale, h = 20 * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let t = NSAffineTransform(); t.scale(by: scale); t.concat()
    NSColor.black.set()
    // Planet limb: a shallow arc across the bottom
    let limbCenter = NSPoint(x: 11, y: -29), limbR: CGFloat = 33
    let limb = NSBezierPath()
    limb.appendArc(withCenter: limbCenter, radius: limbR, startAngle: 71, endAngle: 109)
    limb.lineWidth = 1.6; limb.lineCapStyle = .round
    limb.stroke()
    // Star rising over the limb, clipped to the space above the planet
    NSGraphicsContext.saveGraphicsState()
    let above = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 22, height: 20))
    above.appendOval(in: NSRect(x: limbCenter.x - limbR - 1.6, y: limbCenter.y - limbR - 1.6, width: (limbR + 1.6) * 2, height: (limbR + 1.6) * 2))
    above.windingRule = .evenOdd
    above.addClip()
    let c = NSPoint(x: 11, y: 5.2), r: CGFloat = active ? 5.6 : 5.2
    let sun = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    if active { sun.fill() } else { sun.lineWidth = 1.4; sun.stroke() }
    NSGraphicsContext.restoreGraphicsState()
    if active {
        for deg in [22.0, 56.0, 90.0, 124.0, 158.0] {
            let a = deg * .pi / 180
            let ray = NSBezierPath()
            let r0: CGFloat = deg == 90 ? 8.2 : 7.8, r1: CGFloat = deg == 90 ? 13.6 : 10.4
            ray.move(to: NSPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            ray.line(to: NSPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
            ray.lineWidth = 1.5; ray.lineCapStyle = .round
            ray.stroke()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
let out = CommandLine.arguments[1]
draw(active: true, scale: 1, to: "\(out)/Active.png")
draw(active: true, scale: 2, to: "\(out)/Active@2x.png")
draw(active: false, scale: 1, to: "\(out)/Inactive.png")
draw(active: false, scale: 2, to: "\(out)/Inactive@2x.png")
