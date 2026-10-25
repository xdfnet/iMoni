import AppKit

// 一处设计，两处产物：
//   1. iMoni/Assets.xcassets/AppIcon.appiconset  —— 旧版 macOS 的 AppIcon.icns（浅色）
//   2. iMoni/AppIcon.icon                         —— macOS 26+ 的新图标格式
//      浅色 / 深色 / 单色（着色）三套外观由系统按当前外观自动切换
//
// 运行：swift Scripts/gen_icon.swift

let root = "/Users/admin/iCode/iMoni"
let appiconSet = "\(root)/iMoni/Assets.xcassets/AppIcon.appiconset"
let iconBundle = "\(root)/iMoni/AppIcon.icon"
let iconAssets = "\(iconBundle)/Assets"

// 配色：浅色外观用深一档的蓝，深色外观用亮蓝，单色外观用白（由系统着色）
let symbolLight = NSColor(calibratedRed: 0.04, green: 0.45, blue: 0.90, alpha: 1)
let symbolDark = NSColor(calibratedRed: 0.13, green: 0.55, blue: 1.00, alpha: 1)

// 图案（display.2）整体位置：偏下一点
let symbolOffsetY = -0.015
// 图案占画布比例
let symbolScale = 0.78

// MARK: - 绘制

func newCanvas(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    return rep
}

func png(_ rep: NSBitmapImageRep) -> Data {
    rep.representation(using: .png, properties: [:])!
}

/// 圆角渐变底（旧版 icns 用）
func renderBackground(_ px: Int) -> NSBitmapImageRep {
    let rep = newCanvas(px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.08
    let rect = CGRect(x: inset, y: inset, width: s - inset*2, height: s - inset*2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.85, green: 0.86, blue: 0.89, alpha: 1),
    ])!.draw(in: path, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// 双屏符号（透明底）
func renderSymbol(_ px: Int, _ color: NSColor) -> NSBitmapImageRep {
    let rep = newCanvas(px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let cfg = NSImage.SymbolConfiguration(pointSize: s * symbolScale, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "display.2", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        color.set()
        let r = NSRect(origin: .zero, size: sym.size)
        sym.draw(in: r)
        r.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let sw = sym.size.width, sh = sym.size.height
        let scale = (s * symbolScale) / max(sw, sh)
        let dw = sw * scale, dh = sh * scale
        tinted.draw(in: NSRect(x: (s - dw)/2, y: (s - dh)/2 + s * symbolOffsetY, width: dw, height: dh))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// 旧版 icns 用：圆角底 + 符号合成一张
func renderLegacy(_ px: Int) -> NSBitmapImageRep {
    let rep = newCanvas(px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.08
    let rect = CGRect(x: inset, y: inset, width: s - inset*2, height: s - inset*2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.85, green: 0.86, blue: 0.89, alpha: 1),
    ])!.draw(in: path, angle: -90)

    let cfg = NSImage.SymbolConfiguration(pointSize: s * symbolScale * 0.9, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "display.2", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        symbolLight.set()
        let r = NSRect(origin: .zero, size: sym.size)
        sym.draw(in: r)
        r.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let sw = sym.size.width, sh = sym.size.height
        let scale = (s * symbolScale * 0.9) / max(sw, sh)
        let dw = sw * scale, dh = sh * scale
        tinted.draw(in: NSRect(x: (s - dw)/2, y: (s - dh)/2 + s * symbolOffsetY, width: dw, height: dh))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// MARK: - 1. 旧版 AppIcon.appiconset（浅色）

try? FileManager.default.removeItem(atPath: appiconSet)
try! FileManager.default.createDirectory(atPath: appiconSet, withIntermediateDirectories: true)

var images: [[String: Any]] = []
for base in [16, 32, 128, 256, 512] {
    for (scaleSuffix, scale) in [("", 1), ("@2x", 2)] {
        let px = base * scale
        let filename = "icon_\(base)x\(base)\(scaleSuffix).png"
        try! png(renderLegacy(px)).write(to: URL(fileURLWithPath: "\(appiconSet)/\(filename)"))
        images.append([
            "filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(base)x\(base)",
        ])
    }
}

let contents: [String: Any] = [
    "images": images,
    "info": ["author": "xcode", "version": 1],
]
let contentsData = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! contentsData.write(to: URL(fileURLWithPath: "\(appiconSet)/Contents.json"))

// MARK: - 2. macOS 26+ 的 AppIcon.icon（浅色 / 深色 / 单色三套外观）

try? FileManager.default.removeItem(atPath: iconBundle)
try! FileManager.default.createDirectory(atPath: iconAssets, withIntermediateDirectories: true)

try! png(renderSymbol(1024, symbolLight)).write(to: URL(fileURLWithPath: "\(iconAssets)/sym-light.png"))
try! png(renderSymbol(1024, symbolDark)).write(to: URL(fileURLWithPath: "\(iconAssets)/sym-dark.png"))
try! png(renderSymbol(1024, .white)).write(to: URL(fileURLWithPath: "\(iconAssets)/sym-mono.png"))

/// 同一图层按外观切换可见性：base 档写第一项（不带 appearance），其余按 appearance 覆盖
func opacity(_ light: Double, _ dark: Double, _ tinted: Double) -> [[String: Any]] {
    [
        ["value": light],
        ["appearance": "dark", "value": dark],
        ["appearance": "tinted", "value": tinted],
    ]
}

func layer(_ name: String, _ image: String, _ opacity: [[String: Any]]) -> [String: Any] {
    [
        "name": name,
        "image-name": image,
        "position": ["scale": 1.0, "translation-in-points": [0, 0]],
        "fill": "none",
        "opacity-specializations": opacity,
    ]
}

let iconDocument: [String: Any] = [
    "fill": "automatic",
    "groups": [[
        "name": "Icon",
        "layers": [
            layer("sym-light", "sym-light.png", opacity(1.0, 0.0, 0.0)),
            layer("sym-dark", "sym-dark.png", opacity(0.0, 1.0, 0.0)),
            layer("sym-mono", "sym-mono.png", opacity(0.0, 0.0, 1.0)),
        ],
        "shadow": ["kind": "neutral", "opacity": 0.35],
    ]],
    "supported-platforms": ["circles": ["watchOS"], "squares": "shared"],
]
let iconData = try! JSONSerialization.data(withJSONObject: iconDocument, options: [.prettyPrinted, .sortedKeys])
try! iconData.write(to: URL(fileURLWithPath: "\(iconBundle)/icon.json"))

print("icon ready: \(images.count) legacy images + 3 appearance layers")
