// The beer glass as a menu bar icon — a mug with a handle.
//
//   full     filled to the rim, a head of foam on top
//   empty    bare mug, no head
//   busy     the level sinks and rises, the head rides along
//
// Drawn as a template image: one colour, which the menu bar tints
// according to the appearance. Because there is no second colour, a
// seam separates the foam from the beer and the bubbles are gaps,
// not bright dots.
//
// Deliberately in a file of its own: that way preview-icon.swift can
// render and show it on its own, without starting the app.

import AppKit

enum Glass {
	static let size = NSSize(width: 15, height: 17)

	static func image(full: Bool) -> NSImage {
		render(level: full ? 1.0 : 0.0, foam: full)
	}

	/// One frame of the busy animation: the level swings between a good
	/// third and nearly full. phase keeps running forever.
	static func busy(phase: CGFloat) -> NSImage {
		let t = phase.truncatingRemainder(dividingBy: 1.0)
		let swing = (1 - cos(t * 2 * .pi)) / 2 // 0 … 1 … 0, smooth
		return render(level: 0.35 + 0.6 * swing, foam: true)
	}

	// MARK: - Zeichnen

	private static let line = 1.2

	private static func render(level: CGFloat, foam: Bool) -> NSImage {
		let image = NSImage(size: size, flipped: false) { rect in
			// Krug links, Henkel rechts. Der Schaum braucht oben Platz,
			// also endet der Korpus unter der Bildkante.
			let left = rect.minX + 1.5
			let right = left + 9.0
			let bottom = rect.minY + line / 2 + 0.4
			let rim = rect.maxY - 4.2

			NSColor.black.setStroke()
			NSColor.black.setFill()

			// Der Absatz wird zweimal behandelt: gestrichelt sichtbar im
			// empty mug, as a gap in the filled one.
			drawBase(left: left, right: right, bottom: bottom, erase: false)

			if level > 0 {
				let surface = bottom + (rim - bottom) * min(level, 1.0)
				drawBeer(left: left, right: right, bottom: bottom, to: surface)
				drawBubbles(left: left, right: right, bottom: bottom, below: surface)
				drawBase(left: left, right: right, bottom: bottom, erase: true)
				if foam { drawFoam(left: left, right: right, at: surface, rim: rim) }
			}

			// Outline last, so it stays visible on top of the fill.
			drawBody(left: left, right: right, bottom: bottom, rim: rim)
			drawHandle(at: right, bottom: bottom, rim: rim)
			return true
		}
		image.isTemplate = true // follows light/dark automatically
		return image
	}

	/// Body: open at the top, rounded at the bottom, with the ridge above the foot.
	private static func drawBody(left: CGFloat, right: CGFloat,
	                             bottom: CGFloat, rim: CGFloat)
	{
		let radius = 1.3
		let body = NSBezierPath()
		body.move(to: NSPoint(x: left, y: rim))
		body.line(to: NSPoint(x: left, y: bottom + radius))
		body.appendArc(withCenter: NSPoint(x: left + radius, y: bottom + radius),
		               radius: radius, startAngle: 180, endAngle: 270)
		body.line(to: NSPoint(x: right - radius, y: bottom))
		body.appendArc(withCenter: NSPoint(x: right - radius, y: bottom + radius),
		               radius: radius, startAngle: 270, endAngle: 360)
		body.line(to: NSPoint(x: right, y: rim))
		body.lineWidth = line
		body.lineJoinStyle = .round
		body.lineCapStyle = .butt
		body.stroke()
	}

	/// The ridge just above the base, as in the original.
	private static func drawBase(left: CGFloat, right: CGFloat,
	                             bottom: CGFloat, erase: Bool)
	{
		let base = NSBezierPath()
		base.move(to: NSPoint(x: left + 0.4, y: bottom + 2.0))
		base.line(to: NSPoint(x: right - 0.4, y: bottom + 2.0))
		base.lineWidth = line * 0.7
		if erase {
			NSGraphicsContext.current?.compositingOperation = .destinationOut
			base.stroke()
			NSGraphicsContext.current?.compositingOperation = .sourceOver
		} else {
			base.stroke()
		}
	}

	/// Henkel: ein Ring rechts am Korpus. Die linke Kante liegt auf der
	/// Krugwand und verschwindet darin.
	private static func drawHandle(at x: CGFloat, bottom: CGFloat, rim: CGFloat) {
		let span = rim - bottom
		let handle = NSBezierPath(
			roundedRect: NSRect(x: x, y: bottom + span * 0.20,
			                    width: 3.2, height: span * 0.60),
			xRadius: 1.4, yRadius: 1.4
		)
		handle.lineWidth = line
		handle.stroke()
	}

	private static func drawBeer(left: CGFloat, right: CGFloat,
	                             bottom: CGFloat, to surface: CGFloat)
	{
		// Flush with the inner edge of the outline — an inset beer
		// sieht aus wie ein Rechteck, das im Krug schwebt.
		let inset = line / 2 - 0.1
		let beer = NSBezierPath(roundedRect: NSRect(
			x: left + inset, y: bottom + inset,
			width: (right - left) - inset * 2,
			height: max(0, surface - bottom - inset)
		), xRadius: 0.9, yRadius: 0.9)
		beer.fill()
	}

	/// Blasen sind aus dem Bier ausgestanzt — ein Template-Bild kennt
	/// no second colour, the gap is the bubble.
	private static func drawBubbles(left: CGFloat, right: CGFloat,
	                                bottom: CGFloat, below surface: CGFloat)
	{
		let spots: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
			(0.34, 0.62, 0.85), (0.66, 0.42, 0.65), (0.45, 0.24, 0.5),
		]
		NSGraphicsContext.current?.compositingOperation = .destinationOut
		for s in spots {
			let cy = bottom + (surface - bottom) * s.y
			// Nur zeichnen, wenn die Blase ganz im Bier liegt.
			guard cy + s.r < surface - 0.3, cy - s.r > bottom + 0.3 else { continue }
			let cx = left + (right - left) * s.x
			NSBezierPath(ovalIn: NSRect(x: cx - s.r, y: cy - s.r,
			                            width: s.r * 2, height: s.r * 2)).fill()
		}
		NSGraphicsContext.current?.compositingOperation = .sourceOver
	}

	/// Head of foam: a filled dome with a flat bottom and a bulging
	/// Oberkante. Zwischen Bier und Schaum bleibt eine Fuge — sonst
	/// the two merge into one area, because a template image has only
	/// eine Farbe kennt.
	private static func drawFoam(left: CGFloat, right: CGFloat,
	                             at surface: CGFloat, rim: CGFloat)
	{
		// The foam may spill over the rim only if it reaches the top
		// as well — otherwise it would stick through the mug's wall.
		let reach = max(0, min(1, (surface - (rim - 2.0)) / 2.0))
		let overhang = -line / 2 + (0.5 + line / 2) * reach
		let a = left - overhang
		let b = right + overhang
		let gap = 0.9
		let base = surface + gap

		// Unterschiedliche Radien, damit die Krone nicht wie Zinnen wirkt.
		let radii: [CGFloat] = [1.3, 1.6, 1.35, 1.5]
		let step = (b - a) / CGFloat(radii.count)

		let foam = NSBezierPath()
		// Band, das die Kuppen unten verbindet und den Boden gerade macht.
		foam.appendRect(NSRect(x: a, y: base, width: b - a, height: 0.9))
		for (i, r) in radii.enumerated() {
			let cx = a + step * (CGFloat(i) + 0.5)
			foam.appendOval(in: NSRect(x: cx - r, y: base + r * 0.75 - r,
			                           width: r * 2, height: r * 2))
		}
		foam.windingRule = .nonZero
		foam.fill()
	}
}
