import CoreImage
import Foundation
import ImageIO

guard CommandLine.arguments.count == 3 else {
    fputs("usage: extract_foreground.swift <input> <output>\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    fputs("unable to decode input image\n", stderr)
    exit(65)
}

// Imagen supplies a flat #051120 perimeter. A color cube converts only that
// keyed perimeter into alpha while retaining the racket's dark graphite.
let dimension = 64
let background = SIMD3<Float>(5 / 255, 17 / 255, 32 / 255)
var cube = [Float]()
cube.reserveCapacity(dimension * dimension * dimension * 4)
for blue in 0..<dimension {
    for green in 0..<dimension {
        for red in 0..<dimension {
            let color = SIMD3<Float>(
                Float(red) / Float(dimension - 1),
                Float(green) / Float(dimension - 1),
                Float(blue) / Float(dimension - 1)
            )
            let delta = color - background
            let distance = sqrt(
                delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
            )
            let rawAlpha: Float = (distance - 0.025) / 0.060
            let alpha: Float = Swift.max(0, Swift.min(1, rawAlpha))
            cube.append(color.x)
            cube.append(color.y)
            cube.append(color.z)
            cube.append(alpha * alpha * (3 - 2 * alpha))
        }
    }
}

let cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
let foreground = CIImage(cgImage: image).applyingFilter(
    "CIColorCubeWithColorSpace",
    parameters: [
        "inputCubeDimension": dimension,
        "inputCubeData": cubeData,
        "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB)!,
    ]
)

do {
    try CIContext(options: [.cacheIntermediates: false])
        .writePNGRepresentation(
            of: foreground,
            to: outputURL,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            options: [:]
        )
} catch {
    fputs("foreground extraction failed: \(error)\n", stderr)
    exit(70)
}
