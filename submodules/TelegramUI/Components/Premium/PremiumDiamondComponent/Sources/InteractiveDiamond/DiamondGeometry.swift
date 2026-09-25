import simd

// MARK: - Diamond cut

struct DiamondGeometry {
    static let roundingRadius: Float = 0.055
    struct Vertex {
        var position: SIMD4<Float>
        var normal: SIMD4<Float>
        var surface: SIMD4<Float>
    }

    private(set) var vertices: [Vertex] = []
    private(set) var planes: [SIMD4<Float>] = []

    init(roundingRadius: Float = Self.roundingRadius) {
        let girdle: [SIMD2<Float>] = [SIMD2(0.66, 1), SIMD2(1, 0.66),
            SIMD2(1, -0.66), SIMD2(0.66, -1), SIMD2(-0.66, -1),
            SIMD2(-1, -0.66), SIMD2(-1, 0.66), SIMD2(-0.66, 1)]
        let table: [SIMD2<Float>] = [SIMD2(0.50, 0.60), SIMD2(0.60, 0.50),
            SIMD2(0.60, -0.50), SIMD2(0.50, -0.60), SIMD2(-0.50, -0.60),
            SIMD2(-0.60, -0.50), SIMD2(-0.60, 0.50), SIMD2(-0.50, 0.60)]
        let sections: [(scale: Float, y: Float, table: Bool)] = [
            (0.965, 0.600, true), (1, 0.588, true),
            (0.990, 0.025, false), (1, -0.006, false), (0.978, -0.045, false),
            (0.025, -1.035, false), (0.009, -1.051, false)
        ]
        let rings = sections.map { section in
            (0..<8).map { i -> SIMD3<Float> in
                let outline = section.table ? table[i] : girdle[i]
                return SIMD3(outline.x * section.scale, section.y, outline.y * section.scale)
            }
        }

        func face(_ points: [SIMD3<Float>], kind: Float, sector: Int) {
            var p = points
            var n = simd_normalize(simd_cross(p[1] - p[0], p[2] - p[0]))
            let center = p.reduce(.zero, +) / Float(p.count)
            if simd_dot(n, center - SIMD3(0, -0.12, 0)) < 0 {
                p.reverse()
                n = -n
            }
            if kind != 3 { planes.append(SIMD4(n, -simd_dot(n, p[0]))) }
            for j in 1..<(p.count - 1) {
                for k in [0, j, j + 1] {
                    vertices.append(Vertex(position: SIMD4(p[k], 1), normal: SIMD4(n, 0),
                                           surface: SIMD4(0, 0, kind, Float(sector))))
                }
            }
        }
        face(rings[0], kind: 0, sector: 0)
        for band in 0..<(rings.count - 1) {
            for i in 0..<8 {
                let next = (i + 1) % 8
                face([rings[band][i], rings[band + 1][i], rings[band + 1][next], rings[band][next]],
                     kind: band == 1 ? 1 : (band == 4 ? 2 : 3), sector: i)
            }
        }
        face(rings.last!, kind: 3, sector: 0)
        if roundingRadius > 0 {
            vertices = DiamondRounding.mesh(planes: planes, radius: roundingRadius)
        }
    }
}

// MARK: - Rounded edges and corners

enum DiamondRounding {
    private struct Sample {
        let normal: SIMD3<Float>
        let material: SIMD3<Float>
    }

    private struct Edge: Hashable {
        let a: Int
        let b: Int
        init(_ a: Int, _ b: Int) { self.a = min(a, b); self.b = max(a, b) }
    }

    static func mesh(planes: [SIMD4<Float>], radius: Float, segments: Int = 12) -> [DiamondGeometry.Vertex] {
        precondition(radius > 0 && radius <= 0.08 && segments >= 3)
        let normals = planes.map { SIMD3($0.x, $0.y, $0.z) }
        let materials: [SIMD3<Float>] = planes.indices.map {
            $0 == 0 ? SIMD3(1, 0, 0) : ($0 <= 8 ? SIMD3(0, 1, 0) : SIMD3(0, 0, 1))
        }
        let doubleNormals = normals.map { SIMD3<Double>($0) }
        let offsets = planes.map { Double($0.w) + Double(radius) }
        var corners: [SIMD3<Double>] = []

        for a in 0..<(planes.count - 2) {
            for b in (a + 1)..<(planes.count - 1) {
                for c in (b + 1)..<planes.count {
                    let na = doubleNormals[a], nb = doubleNormals[b], nc = doubleNormals[c]
                    let determinant = simd_dot(na, simd_cross(nb, nc))
                    if abs(determinant) < 1e-8 { continue }
                    let point = (-offsets[a] * simd_cross(nb, nc)
                                 - offsets[b] * simd_cross(nc, na)
                                 - offsets[c] * simd_cross(na, nb)) / determinant
                    guard planes.indices.allSatisfy({ simd_dot(doubleNormals[$0], point) + offsets[$0] < 2e-7 })
                    else { continue }
                    if !corners.contains(where: { simd_distance_squared($0, point) < 1e-12 }) {
                        corners.append(point)
                    }
                }
            }
        }
        let points = corners.map { SIMD3<Float>($0) }

        func cyclicOrder(_ indices: [Int], values: [SIMD3<Float>], normal: SIMD3<Float>) -> [Int] {
            let center = indices.reduce(SIMD3<Float>.zero) { $0 + values[$1] } / Float(indices.count)
            let axis = abs(normal.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
            let u = simd_normalize(simd_cross(axis, normal)), v = simd_cross(normal, u)
            return indices.sorted {
                let a = values[$0] - center, b = values[$1] - center
                return atan2(simd_dot(a, v), simd_dot(a, u)) < atan2(simd_dot(b, v), simd_dot(b, u))
            }
        }

        var faces = [[Int]](repeating: [], count: planes.count)
        var incidentFaces = [[Int]](repeating: [], count: corners.count)
        var edgeFaces: [Edge: [Int]] = [:]
        for face in planes.indices {
            let indices = corners.indices.filter { abs(simd_dot(doubleNormals[face], corners[$0]) + offsets[face]) < 1e-6 }
            guard indices.count >= 3 else { continue }
            faces[face] = cyclicOrder(Array(indices), values: points, normal: normals[face])
            for i in faces[face].indices {
                let a = faces[face][i], b = faces[face][(i + 1) % indices.count]
                incidentFaces[a].append(face)
                edgeFaces[Edge(a, b), default: []].append(face)
            }
        }
        precondition(!points.isEmpty && edgeFaces.values.allSatisfy { $0.count == 2 }, "Inset must remain a closed convex solid")

        func blendNormal(_ a: SIMD3<Float>, _ b: SIMD3<Float>, step: Int, count: Int) -> SIMD3<Float> {
            if step == 0 { return a }
            if step == count { return b }
            let t = Float(step) / Float(count)
            return simd_normalize(a * (1 - t) + b * t)
        }

        func blend(_ a: Sample, _ b: Sample, step: Int, count: Int) -> Sample {
            let t = Float(step) / Float(count)
            return Sample(normal: blendNormal(a.normal, b.normal, step: step, count: count),
                          material: a.material * (1 - t) + b.material * t)
        }
        var arcs: [Edge: [Sample]] = [:]
        for adjacent in edgeFaces.values {
            let key = Edge(adjacent[0], adjacent[1])
            let a = Sample(normal: normals[key.a], material: materials[key.a])
            let b = Sample(normal: normals[key.b], material: materials[key.b])
            arcs[key] = (0...segments).map { blend(a, b, step: $0, count: segments) }
        }

        var result: [DiamondGeometry.Vertex] = []
        result.reserveCapacity(18000)
        func vertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>, kind: Float, sector: Float = 0) -> DiamondGeometry.Vertex {
            DiamondGeometry.Vertex(position: SIMD4(p, 1), normal: SIMD4(n, 0), surface: SIMD4(0, 0, kind, sector))
        }
        func roundedVertex(_ index: Int, _ sample: Sample) -> DiamondGeometry.Vertex {
            var v = vertex(points[index] + radius * sample.normal, sample.normal, kind: 3)
            v.surface.x = sample.material.x
            v.surface.y = sample.material.y
            return v
        }
        func triangle(_ a: DiamondGeometry.Vertex, _ b: DiamondGeometry.Vertex, _ c: DiamondGeometry.Vertex) {
            let pa = SIMD3(a.position.x, a.position.y, a.position.z)
            let pb = SIMD3(b.position.x, b.position.y, b.position.z)
            let pc = SIMD3(c.position.x, c.position.y, c.position.z)
            let cross = simd_cross(pb-pa, pc-pa)
            let outward = (pa + pb + pc) / 3 - SIMD3<Float>(0, -0.12, 0)
            if simd_dot(cross, outward) > 0 { result.append(contentsOf: [a, b, c]) }
            else { result.append(contentsOf: [a, c, b]) }
        }
        func quad(_ a: DiamondGeometry.Vertex, _ b: DiamondGeometry.Vertex,
                  _ c: DiamondGeometry.Vertex, _ d: DiamondGeometry.Vertex) {
            triangle(a, b, c)
            triangle(a, c, d)
        }

        for face in faces.indices where faces[face].count >= 3 {
            let n = normals[face]
            let kind: Float = face == 0 ? 0 : (face <= 8 ? 1 : 2)
            let rim = faces[face].map { vertex(points[$0] + radius*n, n, kind: kind, sector: Float((face-1) % 8)) }
            let center = rim.reduce(SIMD4<Float>.zero) { $0 + $1.position } / Float(rim.count)
            let middle = vertex(SIMD3(center.x, center.y, center.z), n, kind: kind)
            for i in rim.indices { triangle(middle, rim[i], rim[(i+1) % rim.count]) }
        }

        for edge in edgeFaces.keys.sorted(by: { $0.a == $1.a ? $0.b < $1.b : $0.a < $1.a }) {
            let adjacent = edgeFaces[edge]!
            let arc = arcs[Edge(adjacent[0], adjacent[1])]!
            for i in 0..<segments {
                quad(roundedVertex(edge.a, arc[i]), roundedVertex(edge.b, arc[i]),
                     roundedVertex(edge.b, arc[i+1]), roundedVertex(edge.a, arc[i+1]))
            }
        }

        let radialSteps = 5
        for corner in points.indices {
            let incident = incidentFaces[corner]
            guard incident.count >= 3 else { continue }
            let centerNormal = simd_normalize(incident.reduce(SIMD3<Float>.zero) { $0 + normals[$1] })
            let centerMaterial = incident.reduce(SIMD3<Float>.zero) { $0 + materials[$1] } / Float(incident.count)
            let centerSample = Sample(normal: centerNormal, material: centerMaterial)
            let ordered = cyclicOrder(incident, values: normals, normal: centerNormal)
            let middle = roundedVertex(corner, centerSample)
            for i in ordered.indices {
                let a = ordered[i], b = ordered[(i+1) % ordered.count]
                let samples = arcs[Edge(a, b)]!
                let arc = a < b ? samples : Array(samples.reversed())
                for j in 0..<segments {
                    func sample(_ side: Int, _ row: Int) -> DiamondGeometry.Vertex {
                        roundedVertex(corner, blend(centerSample, arc[j+side], step: row, count: radialSteps))
                    }
                    triangle(middle, sample(0, 1), sample(1, 1))
                    for row in 1..<radialSteps {
                        quad(sample(0, row), sample(1, row), sample(1, row+1), sample(0, row+1))
                    }
                }
            }
        }
        return result
    }
}

// MARK: - Sparkle geometry

struct DiamondSparkleGeometry {
    struct Vertex {
        var contours: SIMD4<Float>
        var material: SIMD4<Float>
    }
    private struct Outline {
        var vertices: [SIMD2<Float>]
        var incoming: [SIMD2<Float>]
        var outgoing: [SIMD2<Float>]
        func sample(segment i: Int, t: Float) -> SIMD2<Float> {
            let j = (i + 1) % vertices.count
            let a = vertices[i], b = a + outgoing[i]
            let d = vertices[j], c = d + incoming[j]
            let s = 1 - t
            return a * (s*s*s) + b * (3*s*s*t) + c * (3*s*t*t) + d * (t*t*t)
        }
    }

    let main: [Vertex]
    let small: [Vertex]

    init() {
        func tessellate(_ wide: Outline, _ narrow: Outline, layer: Float) -> [Vertex] {
            var result: [Vertex] = []
            for segment in wide.vertices.indices {
                for step in 0..<16 {
                    let t0 = Float(step) / 16, t1 = Float(step + 1) / 16
                    for t in [Float(-1), t0, t1] {
                        let a = t < 0 ? SIMD2<Float>.zero : wide.sample(segment: segment, t: t)
                        let b = t < 0 ? SIMD2<Float>.zero : narrow.sample(segment: segment, t: t)
                        result.append(Vertex(contours: SIMD4(a.x, a.y, b.x, b.y),
                                             material: SIMD4(layer, 0, 0, 0)))
                    }
                }
            }
            return result
        }
        main = tessellate(Self.circle, Self.circle, layer: 0)
             + tessellate(Self.haloWide, Self.haloNarrow, layer: 1)
             + tessellate(Self.coreWide, Self.coreNarrow, layer: 2)
        let smallCircle = Outline(vertices: Self.circle.vertices.map { $0 * (256 / 108.5) },
                                  incoming: Self.circle.incoming.map { $0 * (256 / 108.5) },
                                  outgoing: Self.circle.outgoing.map { $0 * (256 / 108.5) })
        small = tessellate(smallCircle, smallCircle, layer: 3)
              + tessellate(Self.smallCore, Self.smallCore, layer: 4)
    }
    private static let coreWide = Outline(
        vertices: [SIMD2(1.3, -80.9), SIMD2(17.6, -39.5), SIMD2(38.9, -20.7), SIMD2(80.3, -3.1), SIMD2(38.9, 15.7), SIMD2(17.6, 37), SIMD2(0, 80.9), SIMD2(-17.6, 37), SIMD2(-38.9, 15.7), SIMD2(-80.3, -3.1), SIMD2(-38.9, -20.7), SIMD2(-16.3, -40.8)],
        incoming: [SIMD2(-6.3, 0), SIMD2(-6.3, -15.1), SIMD2(-11.3, -3.8), SIMD2(0, -6.3), SIMD2(13.8, -5), SIMD2(5, -11.3), SIMD2(6.3, 0), SIMD2(6.3, 16.3), SIMD2(11.3, 3.8), SIMD2(0, 7.5), SIMD2(-15.1, 5), SIMD2(-5, 11.3)],
        outgoing: [SIMD2(5, 0), SIMD2(3.8, 10), SIMD2(13.8, 5), SIMD2(0, 7.5), SIMD2(-11.3, 3.8), SIMD2(-6.3, 16.3), SIMD2(-6.3, 0), SIMD2(-3.8, -11.3), SIMD2(-16.3, -6.3), SIMD2(0, -6.3), SIMD2(11.3, -3.8), SIMD2(6.3, -16.3)])
    private static let coreNarrow = Outline(
        vertices: [SIMD2(1.3, -80.9), SIMD2(9, -23), SIMD2(20.8, -12.6), SIMD2(80.3, -3.1), SIMD2(20.8, 7.6), SIMD2(9, 19.4), SIMD2(0, 80.9), SIMD2(-10.5, 19.4), SIMD2(-22.3, 7.6), SIMD2(-80.3, -3.1), SIMD2(-22.3, -12.6), SIMD2(-9.8, -23.7)],
        incoming: [SIMD2(-6.3, 0), SIMD2(-3.5, -8.4), SIMD2(-6.3, -2.1), SIMD2(0, -6.3), SIMD2(7.7, -2.8), SIMD2(2.8, -6.3), SIMD2(6.3, 0), SIMD2(3.5, 9.1), SIMD2(6.3, 2.1), SIMD2(0, 7.5), SIMD2(-8.4, 2.8), SIMD2(-2.8, 6.3)],
        outgoing: [SIMD2(5, 0), SIMD2(2.1, 5.6), SIMD2(7.7, 2.8), SIMD2(0, 7.5), SIMD2(-6.3, 2.1), SIMD2(-3.5, 9.1), SIMD2(-6.3, 0), SIMD2(-2.1, -6.3), SIMD2(-9.1, -3.5), SIMD2(0, -6.3), SIMD2(6.3, -2.1), SIMD2(3.5, -9.1)])
    private static let haloWide = Outline(
        vertices: [SIMD2(1.8, -113.5), SIMD2(24.6, -55.4), SIMD2(54.6, -29), SIMD2(112.7, -4.4), SIMD2(54.6, 22), SIMD2(24.6, 51.9), SIMD2(0, 113.5), SIMD2(-24.6, 51.9), SIMD2(-54.6, 22), SIMD2(-112.7, -4.4), SIMD2(-54.6, -29), SIMD2(-22.9, -57.2)],
        incoming: [SIMD2(-8.8, 0), SIMD2(-8.8, -21.1), SIMD2(-15.8, -5.3), SIMD2(0, -8.8), SIMD2(19.4, -7), SIMD2(7, -15.8), SIMD2(8.8, 0), SIMD2(8.8, 22.9), SIMD2(15.8, 5.3), SIMD2(0, 10.6), SIMD2(-21.1, 7), SIMD2(-7, 15.8)],
        outgoing: [SIMD2(7, 0), SIMD2(5.3, 14.1), SIMD2(19.4, 7), SIMD2(0, 10.6), SIMD2(-15.8, 5.3), SIMD2(-8.8, 22.9), SIMD2(-8.8, 0), SIMD2(-5.3, -15.8), SIMD2(-22.9, -8.8), SIMD2(0, -8.8), SIMD2(15.8, -5.3), SIMD2(8.8, -22.9)])
    private static let haloNarrow = Outline(
        vertices: [SIMD2(1.8, -113.5), SIMD2(12.9, -32), SIMD2(29.5, -17.3), SIMD2(112.7, -4.4), SIMD2(29.5, 11), SIMD2(12.9, 27.7), SIMD2(0, 113.5), SIMD2(-14.5, 27.7), SIMD2(-31.1, 11), SIMD2(-112.7, -4.4), SIMD2(-31.1, -17.3), SIMD2(-13.5, -32.9)],
        incoming: [SIMD2(-8.8, 0), SIMD2(-4.9, -11.7), SIMD2(-8.8, -2.9), SIMD2(0, -8.8), SIMD2(10.7, -3.9), SIMD2(3.9, -8.8), SIMD2(8.8, 0), SIMD2(4.9, 12.7), SIMD2(8.8, 2.9), SIMD2(0, 10.6), SIMD2(-11.7, 3.9), SIMD2(-3.9, 8.8)],
        outgoing: [SIMD2(7, 0), SIMD2(2.9, 7.8), SIMD2(10.7, 3.9), SIMD2(0, 10.6), SIMD2(-8.8, 2.9), SIMD2(-4.9, 12.7), SIMD2(-8.8, 0), SIMD2(-2.9, -8.8), SIMD2(-12.7, -4.9), SIMD2(0, -8.8), SIMD2(8.8, -2.9), SIMD2(4.9, -12.7)])
    private static let circle = Outline(
        vertices: [SIMD2(108.5, 0), SIMD2(0, 108.5), SIMD2(-108.5, 0), SIMD2(0, -108.5)],
        incoming: [SIMD2(0, -59.9), SIMD2(59.9, 0), SIMD2(0, 59.9), SIMD2(-59.9, 0)],
        outgoing: [SIMD2(0, 59.9), SIMD2(-59.9, 0), SIMD2(0, -59.9), SIMD2(59.9, 0)])
    private static let smallCore = Outline(
        vertices: [SIMD2(0, -53.2), SIMD2(53.2, 0), SIMD2(0, 53.2), SIMD2(-53.2, 0)],
        incoming: [SIMD2(-3.1, 50.4), SIMD2(-50.8, -2.9), SIMD2(2.1, -49.7), SIMD2(50.1, 3.5)],
        outgoing: [SIMD2(2.5, 50.2), SIMD2(-50.8, 3.5), SIMD2(-3.1, -49.7), SIMD2(50.1, -2.7)])
}

// MARK: - Transforms

enum DiamondMath {
    static func rotation(x: Float, y: Float) -> simd_float4x4 {
        let pitch = simd_quatf(angle: x, axis: SIMD3(1, 0, 0))
        let yaw = simd_quatf(angle: y, axis: SIMD3(0, 1, 0))
        return simd_float4x4(pitch * yaw)
    }

    static func projection(aspect: Float, zoom: Float) -> simd_float4x4 {
        let halfHeight = Float(1.52) / zoom * max(1, 1 / max(aspect, 0.01))
        let halfWidth = halfHeight * aspect
        return simd_float4x4(columns: (
            SIMD4(1 / halfWidth, 0, 0, 0), SIMD4(0, 1 / halfHeight, 0, 0),
            SIMD4(0, 0, -1 / 12, 0), SIMD4(0, 0.12 / halfHeight, 0.5, 1)
        ))
    }
}
