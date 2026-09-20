// Rendert die Glas-Zustände als PNG, damit man sie ansehen kann, ohne die
// App zu starten:
//
//   swiftc -o /tmp/preview Glass.swift preview-icon.swift -framework AppKit
//   /tmp/preview /tmp/glas
//
// Schreibt voll.png, leer.png, sechs Einzelbilder der Animation und
// pixel.png — die drei Zustände in echter Menüleisten-Größe, hart
// vergrößert. Das ist die Ansicht, die zählt: alles andere schmeichelt.
// Die Menüleiste zeichnet das Bild als Template, also schwarz auf hell
// bzw. weiß auf dunkel. Hier kommt es schwarz auf weiß heraus.

import AppKit

func write(_ image: NSImage, scale: CGFloat, to path: String) {
	let pixels = NSSize(width: image.size.width * scale, height: image.size.height * scale)
	guard let rep = NSBitmapImageRep(
		bitmapDataPlanes: nil,
		pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
		bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
		colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
	) else { return }

	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
	NSColor.white.setFill()
	NSRect(origin: .zero, size: pixels).fill()
	image.draw(in: NSRect(origin: .zero, size: pixels))
	NSGraphicsContext.restoreGraphicsState()

	if let data = rep.representation(using: .png, properties: [:]) {
		try? data.write(to: URL(fileURLWithPath: path))
		print("geschrieben: \(path)")
	}
}

/// Alle Einzelbilder nebeneinander, damit die Bewegung auf einen Blick
/// zu beurteilen ist.
func writeStrip(_ images: [NSImage], scale: CGFloat, to path: String) {
	guard let first = images.first else { return }
	let gap: CGFloat = 4
	let w = (first.size.width * scale + gap) * CGFloat(images.count) + gap
	let h = first.size.height * scale + gap * 2
	guard let rep = NSBitmapImageRep(
		bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h),
		bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
		colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
	) else { return }

	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
	NSColor.white.setFill()
	NSRect(x: 0, y: 0, width: w, height: h).fill()
	for (i, image) in images.enumerated() {
		let x = gap + (first.size.width * scale + gap) * CGFloat(i)
		image.draw(in: NSRect(x: x, y: gap,
		                      width: image.size.width * scale,
		                      height: image.size.height * scale))
	}
	NSGraphicsContext.restoreGraphicsState()

	if let data = rep.representation(using: .png, properties: [:]) {
		try? data.write(to: URL(fileURLWithPath: path))
		print("geschrieben: \(path)")
	}
}

/// In Retina-Originalgröße rendern, dann ohne Glättung vergrößern — so
/// sieht man, was in der Menüleiste wirklich ankommt.
func writePixels(_ images: [NSImage], zoom: Int, to path: String) {
	let w = Int(Glass.size.width * 2), h = Int(Glass.size.height * 2)
	let outW = (w * zoom + 10) * images.count, outH = h * zoom + 20
	guard let out = NSBitmapImageRep(
		bitmapDataPlanes: nil, pixelsWide: outW, pixelsHigh: outH,
		bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
		colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
	) else { return }

	NSGraphicsContext.saveGraphicsState()
	NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
	NSColor.white.setFill()
	NSRect(x: 0, y: 0, width: outW, height: outH).fill()
	for (i, image) in images.enumerated() {
		guard let small = NSBitmapImageRep(
			bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
			bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
			colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
		) else { continue }
		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: small)
		image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
		NSGraphicsContext.restoreGraphicsState()

		NSGraphicsContext.current?.imageInterpolation = .none
		small.draw(in: NSRect(x: i * (w * zoom + 10) + 5, y: 10,
		                      width: w * zoom, height: h * zoom))
	}
	NSGraphicsContext.restoreGraphicsState()

	if let data = out.representation(using: .png, properties: [:]) {
		try? data.write(to: URL(fileURLWithPath: path))
		print("geschrieben: \(path)  (\(w)x\(h) Pixel je Symbol)")
	}
}

@main
enum Preview {
	static func main() {
		let args = CommandLine.arguments
		let dir = args.count > 1 ? args[1] : "/tmp/glas"
		let scale: CGFloat = args.count > 2 ? CGFloat(Double(args[2]) ?? 12) : 12
		try? FileManager.default.createDirectory(atPath: dir,
		                                         withIntermediateDirectories: true)

		write(Glass.image(full: true), scale: scale, to: "\(dir)/voll.png")
		write(Glass.image(full: false), scale: scale, to: "\(dir)/leer.png")

		let frames = (0 ..< 6).map { Glass.busy(phase: CGFloat($0) / 6.0) }
		for (i, frame) in frames.enumerated() {
			write(frame, scale: scale, to: "\(dir)/arbeit-\(i).png")
		}
		writeStrip(frames, scale: scale, to: "\(dir)/arbeit-streifen.png")

		writePixels([Glass.image(full: true),
		             Glass.image(full: false),
		             Glass.busy(phase: 0.25)],
		            zoom: 10, to: "\(dir)/pixel.png")
	}
}
