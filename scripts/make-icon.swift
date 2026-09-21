// Generates the app icon sizes from Assets/App_logo.png.
//
// The artwork is a squircle plate that fills almost the whole frame. Depending
// on how it was exported it either carries real transparency outside the plate,
// or — as with the current file — sits on opaque black. Both are handled: the
// background is keyed out, the plate is trimmed to its own bounds, and the
// result is scaled to fill the canvas completely so the Dock tile goes
// edge-to-edge like a native macOS 26 icon.
//
// Output is an .iconset of PNGs. Wiring them into the app is two more steps,
// both of which expect the same file names:
//
//   swift scripts/make-icon.swift                       # -> scripts/AppIcon.iconset
//   cp scripts/AppIcon.iconset/*.png Assets.xcassets/AppIcon.appiconset/
//   iconutil -c icns scripts/AppIcon.iconset -o App/AppIcon.icns
//
// make-app.sh compiles the asset catalog when Xcode is present and falls back
// to App/AppIcon.icns when it is not, so both destinations matter.
//
//   swift scripts/make-icon.swift [outputIconset]

import AppKit

let root = FileManager.default.currentDirectoryPath
let sourcePath = "\(root)/Assets/App_logo.png"
let iconsetPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "\(root)/scripts/AppIcon.iconset"

guard let image = NSImage(contentsOfFile: sourcePath),
      let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("error: cannot read \(sourcePath)\n".utf8))
    exit(1)
}

let w = source.width, h = source.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))

func idx(_ x: Int, _ y: Int) -> Int { (y * w + x) * 4 }
func lum(_ i: Int) -> Double {
    0.299 * Double(px[i]) + 0.587 * Double(px[i + 1]) + 0.114 * Double(px[i + 2])
}

// If the export already has transparency, trust it. Otherwise key out the dark
// background by flooding inward from the corners, which only ever reaches the
// area outside the plate — the plate's interior is never dark enough to leak.
let alreadyTransparent = (0..<(w * h)).contains { px[$0 * 4 + 3] < 250 }
var isBackground = [Bool](repeating: false, count: w * h)

if alreadyTransparent {
    for p in 0..<(w * h) where px[p * 4 + 3] <= 8 { isBackground[p] = true }
    print("source has alpha; using it directly")
} else {
    let darkCutoff = 40.0
    var stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    while let (x, y) = stack.popLast() {
        guard x >= 0, y >= 0, x < w, y < h else { continue }
        let p = y * w + x
        if isBackground[p] { continue }
        guard lum(p * 4) < darkCutoff else { continue }
        isBackground[p] = true
        stack.append((x + 1, y)); stack.append((x - 1, y))
        stack.append((x, y + 1)); stack.append((x, y - 1))
    }
    let filled = isBackground.filter { $0 }.count
    print(String(format: "keyed opaque background: %d px (%.1f%% of canvas)",
                 filled, Double(filled) / Double(w * h) * 100))

    // Recover the antialiased rim. Edge pixels are plate colour blended toward
    // black, so coverage = luminance / local plate luminance; unpremultiplying
    // by that restores the original colour and gives a soft edge instead of a
    // hard stair-step.
    var alpha = [UInt8](repeating: 255, count: w * h)
    for p in 0..<(w * h) where isBackground[p] { alpha[p] = 0 }
    let band = 3
    var rim = 0
    for y in 0..<h {
        for x in 0..<w {
            let p = y * w + x
            guard !isBackground[p] else { continue }
            var nearBackground = false
            var localPlate = 0.0
            for dy in -band...band {
                for dx in -band...band {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
                    let q = ny * w + nx
                    if isBackground[q] { nearBackground = true }
                    else { localPlate = max(localPlate, lum(q * 4)) }
                }
            }
            guard nearBackground, localPlate > 1 else { continue }
            let coverage = min(1.0, lum(p * 4) / localPlate)
            alpha[p] = UInt8(max(0, min(255, coverage * 255)))
            if coverage > 0.004 {
                for ch in 0..<3 {
                    px[idx(x, y) + ch] = UInt8(min(255, Double(px[idx(x, y) + ch]) / coverage))
                }
            }
            rim += 1
        }
    }
    for p in 0..<(w * h) { px[p * 4 + 3] = alpha[p] }
    print("recovered \(rim) rim pixels with matte extraction")
}

// Rebuild a CGImage carrying the new alpha.
let keyed = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!

var mnX = w, mnY = h, mxX = -1, mxY = -1
for y in 0..<h {
    for x in 0..<w where px[idx(x, y) + 3] > 8 {
        mnX = min(mnX, x); mxX = max(mxX, x); mnY = min(mnY, y); mxY = max(mxY, y)
    }
}
let crop = CGRect(x: mnX, y: mnY, width: mxX - mnX + 1, height: mxY - mnY + 1)
let art = keyed.cropping(to: crop)!
print(String(format: "plate trimmed to %dx%d (aspect %.4f) from (%d,%d)",
             Int(crop.width), Int(crop.height), crop.width / crop.height, mnX, mnY))

let targets: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

try? FileManager.default.removeItem(atPath: iconsetPath)
try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Fill the canvas completely. The plate is within half a percent of square, so
// squaring it up is invisible and buys an exact edge-to-edge tile.
for (name, side) in targets {
    let s = CGFloat(side)
    let out = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    out.clear(CGRect(x: 0, y: 0, width: s, height: s))
    out.interpolationQuality = .high
    out.draw(art, in: CGRect(x: 0, y: 0, width: s, height: s))
    let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
    rep.size = NSSize(width: side, height: side)
    try rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}
print("wrote \(targets.count) sizes to \(iconsetPath)")
