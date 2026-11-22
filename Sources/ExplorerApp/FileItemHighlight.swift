import AppKit

@MainActor
enum FileItemHighlight {
    static func draw(in rect: NSRect, selected: Bool, hovered: Bool,
                     dropTarget: Bool = false, radius: CGFloat = 3) {
        guard selected || hovered || dropTarget else { return }
        let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSColor.controlAccentColor.withAlphaComponent(selected || dropTarget ? 0.12 : 0.10).setFill()
        shape.fill()
        if selected || dropTarget {
            NSColor.controlAccentColor.withAlphaComponent(dropTarget ? 1 : 0.55).setStroke()
            shape.lineWidth = dropTarget ? 2 : 1
            shape.stroke()
        }
    }
}
