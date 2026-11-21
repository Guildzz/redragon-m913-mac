// Gera o AppIcon.icns: logo da Redragon em vermelho sobre fundo escuro arredondado.
import AppKit
let svg = NSImage(contentsOfFile: CommandLine.arguments[1])!
let saida = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: saida, withIntermediateDirectories: true)
for (nome, px) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px), m = s * 0.1
    let fundo = NSRect(x: m, y: m, width: s - 2*m, height: s - 2*m)
    let caminho = NSBezierPath(roundedRect: fundo, xRadius: fundo.width * 0.225, yRadius: fundo.width * 0.225)
    NSGradient(starting: NSColor(white: 0.16, alpha: 1), ending: NSColor(white: 0.06, alpha: 1))!.draw(in: caminho, angle: -90)
    let logo = fundo.insetBy(dx: fundo.width * 0.18, dy: fundo.width * 0.18)
    let tinta = NSImage(size: logo.size, flipped: false) { r in
        svg.draw(in: r)
        NSColor(red: 0.89, green: 0.11, blue: 0.14, alpha: 1).set()
        r.fill(using: .sourceAtop)
        return true
    }
    tinta.draw(in: logo)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(saida)/icon_\(nome).png"))
}
