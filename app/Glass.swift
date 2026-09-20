// Das Bierglas als Menüleisten-Symbol — ein Krug mit Henkel.
//
//   voll      Füllung bis zum Rand, Schaumkrone darüber
//   leer      nackter Krug, keine Krone
//   arbeitend der Füllstand senkt und hebt sich, die Krone schwimmt mit
//
// Gezeichnet wird als Template-Bild: eine Farbe, die die Menüleiste je
// nach Erscheinungsbild einfärbt. Weil es keine zweite Farbe gibt,
// trennt eine Fuge den Schaum vom Bier und die Blasen sind Lücken,
// keine hellen Punkte.
//
// Bewusst in einer eigenen Datei: so lässt es sich mit preview-icon.swift
// einzeln rendern und ansehen, ohne die App zu starten.

import AppKit

enum Glass {
	static let size = NSSize(width: 15, height: 17)

	static func image(full: Bool) -> NSImage {
		render(level: full ? 1.0 : 0.0, foam: full)
	}

	/// Ein Einzelbild der Arbeits-Animation: der Pegel schwingt zwischen
	/// gut einem Drittel und fast voll. phase läuft endlos weiter.
	static func busy(phase: CGFloat) -> NSImage {
		let t = phase.truncatingRemainder(dividingBy: 1.0)
		let swing = (1 - cos(t * 2 * .pi)) / 2 // 0 … 1 … 0, weich
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
			// leeren Krug, als Lücke im gefüllten.
			drawBase(left: left, right: right, bottom: bottom, erase: false)

			if level > 0 {
				let surface = bottom + (rim - bottom) * min(level, 1.0)
				drawBeer(left: left, right: right, bottom: bottom, to: surface)
				drawBubbles(left: left, right: right, bottom: bottom, below: surface)
				drawBase(left: left, right: right, bottom: bottom, erase: true)
				if foam { drawFoam(left: left, right: right, at: surface, rim: rim) }
			}

			// Kontur zuletzt, damit sie auf der Füllung sichtbar bleibt.
			drawBody(left: left, right: right, bottom: bottom, rim: rim)
			drawHandle(at: right, bottom: bottom, rim: rim)
			return true
		}
		image.isTemplate = true // folgt hell/dunkel automatisch
		return image
	}

	/// Korpus: oben offen, unten abgerundet, mit dem Absatz über dem Fuß.
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

	/// Der Absatz knapp über dem Boden, wie in der Vorlage.
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
		// Bündig an die Innenkante der Kontur — ein eingerücktes Bier
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
	/// keine zweite Farbe, die Lücke ist die Blase.
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

	/// Schaumkrone: eine gefüllte Haube mit flachem Boden und bulliger
	/// Oberkante. Zwischen Bier und Schaum bleibt eine Fuge — sonst
	/// verschmelzen beide zu einer Fläche, weil ein Template-Bild nur
	/// eine Farbe kennt.
	private static func drawFoam(left: CGFloat, right: CGFloat,
	                             at surface: CGFloat, rim: CGFloat)
	{
		// Über den Rand quellen darf der Schaum nur, wenn er auch oben
		// ankommt — sonst stünde er mitten im Krug durch die Wand.
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
