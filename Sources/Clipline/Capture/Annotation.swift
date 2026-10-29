import AppKit
import Combine
import CoreImage

enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow, rectangle, ellipse, line, text, highlight, pixelate, counter

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .pixelate: return "square.grid.3x3.fill"
        case .counter: return "1.circle"
        }
    }

    var title: String {
        switch self {
        case .arrow: return "Pfeil"
        case .rectangle: return "Rahmen"
        case .ellipse: return "Kreis"
        case .line: return "Linie"
        case .text: return "Text"
        case .highlight: return "Marker"
        case .pixelate: return "Verpixeln"
        case .counter: return "Zähler"
        }
    }

    /// Text and counter are placed with a click, everything else is dragged out.
    var isPlaced: Bool { self == .text || self == .counter }
}

struct Annotation: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var width: CGFloat
    var text = ""
    var number = 0

    var rect: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }
}

/// CleanShot-style backdrop: gradient, padding, rounded corners and a soft shadow.
struct BackdropStyle: Identifiable {
    let id: Int
    let name: String
    let from: NSColor
    let to: NSColor

    static let all: [BackdropStyle] = [
        BackdropStyle(id: 0, name: "Himmel", from: NSColor(srgbRed: 0.36, green: 0.70, blue: 0.97, alpha: 1),
                      to: NSColor(srgbRed: 0.23, green: 0.21, blue: 0.89, alpha: 1)),
        BackdropStyle(id: 1, name: "Pfirsich", from: NSColor(srgbRed: 1.00, green: 0.78, blue: 0.62, alpha: 1),
                      to: NSColor(srgbRed: 0.96, green: 0.45, blue: 0.55, alpha: 1)),
        BackdropStyle(id: 2, name: "Minze", from: NSColor(srgbRed: 0.62, green: 0.94, blue: 0.80, alpha: 1),
                      to: NSColor(srgbRed: 0.13, green: 0.62, blue: 0.68, alpha: 1)),
        BackdropStyle(id: 3, name: "Abend", from: NSColor(srgbRed: 0.98, green: 0.62, blue: 0.24, alpha: 1),
                      to: NSColor(srgbRed: 0.55, green: 0.18, blue: 0.62, alpha: 1)),
        BackdropStyle(id: 4, name: "Graphit", from: NSColor(srgbRed: 0.24, green: 0.24, blue: 0.27, alpha: 1),
                      to: NSColor(srgbRed: 0.06, green: 0.06, blue: 0.07, alpha: 1)),
        BackdropStyle(id: 5, name: "Papier", from: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1),
                      to: NSColor(srgbRed: 0.88, green: 0.88, blue: 0.86, alpha: 1)),
    ]
}

final class AnnotationDocument: ObservableObject {
    let image: CGImage
    let size: CGSize
    private(set) lazy var pixelated: CGImage? = Self.pixelate(image)

    @Published private(set) var annotations: [Annotation] = []
    @Published private(set) var draft: Annotation?
    @Published var tool: AnnotationTool = .arrow
    @Published var color: NSColor = .systemRed
    @Published var width: CGFloat
    @Published var pendingText = "Text"
    @Published var backdrop = false { didSet { render() } }
    @Published var backdropStyle = 0 { didSet { render() } }
    /// Padding as a share of the longer image side.
    @Published var padding: CGFloat = 0.08 { didSet { render() } }
    @Published private(set) var preview: NSImage

    static let palette: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .white, .black]

    init?(image nsImage: NSImage) {
        guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        image = cg
        size = CGSize(width: cg.width, height: cg.height)
        width = max(4, round(min(size.width, size.height) / 160))
        preview = nsImage
        render()
    }

    var canvasPadding: CGFloat {
        backdrop ? round(max(size.width, size.height) * padding) : 0
    }

    var canvasSize: CGSize {
        CGSize(width: size.width + 2 * canvasPadding, height: size.height + 2 * canvasPadding)
    }

    // MARK: - Editing (points in image pixels, origin top-left)

    func dragChanged(from start: CGPoint, to end: CGPoint) {
        guard !tool.isPlaced else { return }
        draft = Annotation(tool: tool, start: start, end: end, color: color, width: width)
        render()
    }

    func dragEnded(from start: CGPoint, to end: CGPoint) {
        defer {
            draft = nil
            render()
        }
        if tool.isPlaced {
            var annotation = Annotation(tool: tool, start: end, end: end, color: color, width: width)
            if tool == .text {
                let text = pendingText.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return }
                annotation.text = text
            } else {
                annotation.number = (annotations.filter { $0.tool == .counter }.map(\.number).max() ?? 0) + 1
            }
            annotations.append(annotation)
            return
        }
        guard hypot(end.x - start.x, end.y - start.y) > 4 else { return }
        annotations.append(Annotation(tool: tool, start: start, end: end, color: color, width: width))
    }

    func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        render()
    }

    func clear() {
        annotations.removeAll()
        render()
    }

    // MARK: - Output

    func render() {
        preview = AnnotationRenderer.render(self, maxPixel: 1800)
    }

    func exportPNG() -> Data? {
        let image = AnnotationRenderer.render(self, maxPixel: nil)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    var allAnnotations: [Annotation] {
        draft.map { annotations + [$0] } ?? annotations
    }

    private static func pixelate(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(max(10, CGFloat(image.width) / 70), forKey: kCIInputScaleKey)
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return CIContext().createCGImage(output, from: input.extent)
    }
}

/// One Core Graphics renderer for the live preview and the full-size export.
enum AnnotationRenderer {
    static func render(_ document: AnnotationDocument, maxPixel: CGFloat?) -> NSImage {
        let canvas = document.canvasSize
        let scale = maxPixel.map { min(1, $0 / max(canvas.width, canvas.height)) } ?? 1
        let pixelWidth = max(1, Int(canvas.width * scale))
        let pixelHeight = max(1, Int(canvas.height * scale))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return NSImage(cgImage: document.image, size: document.size) }

        // Work in top-left coordinates, in image pixels.
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: scale, y: -scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }

        let pad = document.canvasPadding
        let imageRect = CGRect(x: pad, y: pad, width: document.size.width, height: document.size.height)

        if document.backdrop {
            let style = BackdropStyle.all[min(document.backdropStyle, BackdropStyle.all.count - 1)]
            if let gradient = CGGradient(colorsSpace: space, colors: [style.from.cgColor, style.to.cgColor] as CFArray,
                                         locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: canvas.width, y: canvas.height),
                                           options: [])
            }
            let radius = max(10, min(document.size.width, document.size.height) * 0.025)
            let path = CGPath(roundedRect: imageRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            // Shadow offsets are in device space: negative height falls downwards.
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -pad * 0.18 * scale), blur: pad * 0.5 * scale,
                              color: NSColor.black.withAlphaComponent(0.35).cgColor)
            context.addPath(path)
            context.setFillColor(NSColor.black.cgColor)
            context.fillPath()
            context.restoreGState()
            context.saveGState()
            context.addPath(path)
            context.clip()
            draw(document.image, in: imageRect, context: context)
            context.restoreGState()
        } else {
            draw(document.image, in: imageRect, context: context)
        }

        context.saveGState()
        context.translateBy(x: pad, y: pad)
        context.clip(to: CGRect(origin: .zero, size: document.size))
        for annotation in document.allAnnotations {
            draw(annotation, document: document, context: context)
        }
        context.restoreGState()

        guard let output = context.makeImage() else { return NSImage(cgImage: document.image, size: document.size) }
        return NSImage(cgImage: output, size: NSSize(width: pixelWidth, height: pixelHeight))
    }

    /// CGImages draw bottom-up; flip locally inside our top-left space.
    private static func draw(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private static func draw(_ annotation: Annotation, document: AnnotationDocument, context: CGContext) {
        let width = annotation.width
        annotation.color.setStroke()
        annotation.color.setFill()

        switch annotation.tool {
        case .rectangle:
            let path = NSBezierPath(roundedRect: annotation.rect, xRadius: width, yRadius: width)
            path.lineWidth = width
            path.stroke()

        case .ellipse:
            let path = NSBezierPath(ovalIn: annotation.rect)
            path.lineWidth = width
            path.stroke()

        case .line:
            let path = NSBezierPath()
            path.move(to: annotation.start)
            path.line(to: annotation.end)
            path.lineWidth = width
            path.lineCapStyle = .round
            path.stroke()

        case .arrow:
            drawArrow(from: annotation.start, to: annotation.end, width: width)

        case .highlight:
            annotation.color.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: annotation.rect, xRadius: width / 2, yRadius: width / 2).fill()

        case .pixelate:
            guard let pixelated = document.pixelated else { return }
            context.saveGState()
            context.clip(to: annotation.rect)
            draw(pixelated, in: CGRect(origin: .zero, size: document.size), context: context)
            context.restoreGState()

        case .text:
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = width
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: width * 5, weight: .bold),
                .foregroundColor: annotation.color,
                .shadow: shadow,
            ]
            let string = NSAttributedString(string: annotation.text, attributes: attributes)
            let size = string.size()
            string.draw(at: CGPoint(x: annotation.start.x - size.width / 2, y: annotation.start.y - size.height / 2))

        case .counter:
            let radius = width * 3
            let circle = CGRect(x: annotation.start.x - radius, y: annotation.start.y - radius,
                                width: radius * 2, height: radius * 2)
            NSBezierPath(ovalIn: circle).fill()
            let ink: NSColor = annotation.color == .white || annotation.color == .systemYellow ? .black : .white
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: radius * 1.1, weight: .bold),
                .foregroundColor: ink,
            ]
            let string = NSAttributedString(string: "\(annotation.number)", attributes: attributes)
            let size = string.size()
            string.draw(at: CGPoint(x: annotation.start.x - size.width / 2, y: annotation.start.y - size.height / 2))
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, width: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = width * 4.5
        let headWidth = width * 3.2
        let base = CGPoint(x: end.x - cos(angle) * headLength, y: end.y - sin(angle) * headLength)

        let shaft = NSBezierPath()
        shaft.move(to: start)
        shaft.line(to: base)
        shaft.lineWidth = width
        shaft.lineCapStyle = .round
        shaft.stroke()

        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: CGPoint(x: base.x + sin(angle) * headWidth, y: base.y - cos(angle) * headWidth))
        head.line(to: CGPoint(x: base.x - sin(angle) * headWidth, y: base.y + cos(angle) * headWidth))
        head.close()
        head.fill()
    }
}
