import Foundation
import Metal
import MetalEngine
import simd

private var metalLibraryValue: MTLLibrary?

func metalLibrary(device: MTLDevice) -> MTLLibrary? {
    if let metalLibraryValue {
        return metalLibraryValue
    }

    let mainBundle = Bundle(for: InteractiveDiamondLayer.self)
    guard let path = mainBundle.path(forResource: "PremiumDiamondComponentBundle", ofType: "bundle"),
          let bundle = Bundle(path: path),
          let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        return nil
    }

    metalLibraryValue = library
    return library
}

final class DiamondRenderer: ComputeState {
    struct StarUniforms {
        var projection: simd_float4x4
        var animation: SIMD4<Float>
        var layout: SIMD4<Float>
    }
    struct Uniforms {
        var model: simd_float4x4
        var projection: simd_float4x4
        var inverseModel: simd_float4x4
        var parameters: SIMD4<Float>
        var viewport: SIMD4<Float>
        var sparkleShape: SIMD4<Float>
        var sparkleHalo: SIMD4<Float>
        var crownGradient: SIMD4<Float>
        var pavilionGradient: SIMD4<Float>
        var lightSweep: SIMD4<Float>
        var crownSweep: SIMD4<Float>
        var rightCrownSweep: SIMD4<Float>
        var leftCrownSweep: SIMD4<Float>
        var pavilionSweep: SIMD4<Float>
        var rightPavilionSweep: SIMD4<Float>
        var leftPavilionSweep: SIMD4<Float>
    }

    enum Failure: LocalizedError {
        case unavailable, resource(String)
        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Metal unavailable"
            case .resource(let name):
                return "Metal resource failure: \(name)."
            }
        }
    }

    let device: MTLDevice
    let sampleCount: Int
    private let pipeline: MTLRenderPipelineState
    private let sparklePipeline: MTLRenderPipelineState
    private let starPipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let sparkleDepthState: MTLDepthStencilState
    private let vertexBuffer: MTLBuffer
    private let planeBuffer: MTLBuffer
    private let mainSparkleBuffer: MTLBuffer
    private let smallSparkleBuffer: MTLBuffer
    private let mainSparkleVertexCount: Int
    private let smallSparkleVertexCount: Int
    private let vertexCount: Int
    private let planeCount: Int

    required convenience init?(device: MTLDevice) {
        do {
            try self.init(device: device, sampleCount: device.supportsTextureSampleCount(4) ? 4 : 1)
        } catch {
            return nil
        }
    }

    private init(device: MTLDevice, sampleCount: Int) throws {
        self.device = device
        self.sampleCount = sampleCount
        let geometry = DiamondGeometry()
        vertexCount = geometry.vertices.count
        planeCount = geometry.planes.count
        guard let vb = geometry.vertices.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }), let pb = geometry.planes.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }) else { throw Failure.resource("geometry") }
        vertexBuffer = vb
        planeBuffer = pb
        vertexBuffer.label = "GramDiamond • bevelled cut"
        planeBuffer.label = "GramDiamond • optical hull"
        let sparkles = DiamondSparkleGeometry()
        mainSparkleVertexCount = sparkles.main.count
        smallSparkleVertexCount = sparkles.small.count
        guard let main = sparkles.main.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }), let small = sparkles.small.withUnsafeBytes({ bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }) else { throw Failure.resource("sparkle contours") }
        mainSparkleBuffer = main
        smallSparkleBuffer = small

        guard let library = metalLibrary(device: device) else {
            throw Failure.resource("PremiumDiamondComponentBundle/default.metallib")
        }

        func makePipeline(vertex: String, fragment: String, blending: Bool) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "GramDiamond • \(fragment)"
            guard let vertexFunction = library.makeFunction(name: vertex),
                  let fragmentFunction = library.makeFunction(name: fragment) else {
                throw Failure.resource("\(vertex) / \(fragment)")
            }
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.rasterSampleCount = sampleCount
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.depthAttachmentPixelFormat = .depth32Float
            if blending {
                let attachment = descriptor.colorAttachments[0]!
                attachment.isBlendingEnabled = true
                attachment.sourceRGBBlendFactor = .one
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        pipeline = try makePipeline(vertex: "diamondVertex", fragment: "diamondFragment", blending: false)
        sparklePipeline = try makePipeline(vertex: "sparkleVertex", fragment: "sparkleFragment", blending: true)
        starPipeline = try makePipeline(vertex: "backgroundStarVertex", fragment: "backgroundStarFragment", blending: true)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        guard let ds = device.makeDepthStencilState(descriptor: depth) else { throw Failure.resource("depth") }
        depthState = ds
        depth.isDepthWriteEnabled = false
        depth.depthCompareFunction = .always
        guard let ss = device.makeDepthStencilState(descriptor: depth) else { throw Failure.resource("sparkle depth") }
        sparkleDepthState = ss
    }

    private func uniforms(size: CGSize, time: Float, motion: DiamondMotion, style: DiamondStyle, reduceMotion: Bool) -> Uniforms {
        let model = DiamondMath.rotation(x: motion.pitch, y: motion.yaw)
        let animationTime = reduceMotion ? 0 : DiamondEntrance.highlightTime(
            at: time, entrance: style.animationMode == .entrance)
        let sparkle = DiamondSparkleAnimation.state(time: animationTime)
        let lookAhead: Float = 1 / 120
        var nextMotion = motion
        nextMotion.step(dt: lookAhead, speed: style.isRotating ? style.rotationSpeed : 0,
                        reduceMotion: reduceMotion, mode: style.animationMode, time: time + lookAhead)
        let yawDelta = atan2(sin(nextMotion.yaw - motion.yaw), cos(nextMotion.yaw - motion.yaw))
        let angularSpeed = simd_length(SIMD2(yawDelta, nextMotion.pitch - motion.pitch)) / lookAhead
        let mainSparkle = DiamondSparkleAnimation.mainPlacement(model: model, angularSpeed: angularSpeed)
        let light = DiamondLightAnimation.state(time: animationTime)
        return Uniforms(model: model,
                        projection: DiamondMath.projection(aspect: Float(size.width / max(size.height, 1)),
                                                           zoom: min(1.6, max(0.6, motion.zoom * style.zoom))),
                        inverseModel: model.transpose,
                        parameters: SIMD4(animationTime, min(1, max(0, style.refraction)), max(0, style.brightness),
                                          style.sparkles && !reduceMotion ? 1 : 0),
                        viewport: SIMD4(Float(size.width), Float(size.height), Float(planeCount), 0),
                        sparkleShape: sparkle.shape,
                        sparkleHalo: SIMD4(sparkle.haloScale, mainSparkle.angle, mainSparkle.height, mainSparkle.visibility),
                        crownGradient: light.crown, pavilionGradient: light.pavilion, lightSweep: light.sweep,
                        crownSweep: light.crownSweep, rightCrownSweep: light.rightCrownSweep,
                        leftCrownSweep: light.leftCrownSweep, pavilionSweep: light.pavilionSweep,
                        rightPavilionSweep: light.rightPavilionSweep, leftPavilionSweep: light.leftPavilionSweep)
    }

    func encode(encoder: MTLRenderCommandEncoder, size: CGSize, time: Float, starBursts: [DiamondStarBurst], motion: DiamondMotion, style: DiamondStyle, reduceMotion: Bool, lightBackground: Bool) {
        var u = uniforms(size: size, time: time, motion: motion, style: style, reduceMotion: reduceMotion)
        if style.backgroundStars && !reduceMotion {
            let entrance = style.animationMode == .entrance
            var stars = StarUniforms(
                projection: DiamondMath.projection(aspect: Float(size.width/max(size.height,1)), zoom: 1),
                animation: SIMD4(0, DiamondEntrance.particleTime(at:time,entrance:entrance),
                                 0, lightBackground ? 1 : 0),
                layout: SIMD4(Float(size.width),Float(size.height),Float(DiamondEntrance.steadyStarCount),0))
            encoder.setCullMode(.none)
            encoder.setDepthStencilState(sparkleDepthState)
            encoder.setRenderPipelineState(starPipeline)
            encoder.setVertexBytes(&stars,length:MemoryLayout<StarUniforms>.stride,index:0)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,
                instanceCount:DiamondEntrance.steadyStarCount)
            for burst in starBursts {
                stars.animation.x = max(0, time - burst.startTime)
                stars.animation.z = 1
                stars.layout.w = Float(burst.seed)
                encoder.setVertexBytes(&stars,length:MemoryLayout<StarUniforms>.stride,index:0)
                encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,
                    instanceCount:DiamondEntrance.burstStarCount,baseInstance:DiamondEntrance.steadyStarCount)
            }
        }
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(.back)
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setVertexBuffer(planeBuffer, offset: 0, index: 2)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.setFragmentBuffer(planeBuffer, offset: 0, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        if style.sparkles && !reduceMotion {
            encoder.setCullMode(.none)
            encoder.setRenderPipelineState(sparklePipeline)
            encoder.setDepthStencilState(sparkleDepthState)
            encoder.setVertexBuffer(mainSparkleBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mainSparkleVertexCount)
            encoder.setVertexBuffer(smallSparkleBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: smallSparkleVertexCount,
                                   instanceCount: 7, baseInstance: 1)
        }
    }
}
