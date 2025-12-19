import Foundation
import UIKit
import MeshTransformApi

private let transformClass: NSObject? = {
    let name = ("CAMutable" as NSString).appendingFormat("MeshTransform")
    if let cls = NSClassFromString(name as String) as AnyObject as? NSObject {
        return cls
    }
    return nil
}()

private let immutableTransformClass: NSObject? = {
    let name = ("CA" as NSString).appendingFormat("MeshTransform")
    if let cls = NSClassFromString(name as String) as AnyObject as? NSObject {
        return cls
    }
    return nil
}()

@inline(__always)
private func getMethod<T>(object: NSObject, selector: String) -> T? {
    guard let method = object.method(for: NSSelectorFromString(selector)) else {
        return nil
    }
    return unsafeBitCast(method, to: T.self)
}

private var cachedTransformCreateMethod: (@convention(c) (AnyObject, Selector) -> NSObject?, Selector)?
private func invokeTransformCreateMethod() -> NSObject? {
    guard let transformClass = transformClass else {
        return nil
    }
    if let cachedTransformCreateMethod {
        return cachedTransformCreateMethod.0(transformClass, cachedTransformCreateMethod.1)
    } else {
        let method: (@convention(c) (AnyObject, Selector) -> NSObject?)? = getMethod(object: transformClass, selector: "meshTransform")
        if let method {
            let selector = NSSelectorFromString("meshTransform")
            cachedTransformCreateMethod = (method, selector)
            return method(transformClass, selector)
        } else {
            return nil
        }
    }
}

private var cachedTransformAddFaceMethod: (@convention(c) (AnyObject, Selector, MeshTransformMeshFace) -> Void, Selector)?
private func invokeTransformAddFaceMethod(object: NSObject, face: MeshTransformMeshFace) {
    if let cachedTransformAddFaceMethod {
        return cachedTransformAddFaceMethod.0(object, cachedTransformAddFaceMethod.1, face)
    } else {
        let method: (@convention(c) (AnyObject, Selector, MeshTransformMeshFace) -> Void)? = getMethod(object: object, selector: "addFace:")
        if let method {
            let selector = NSSelectorFromString("addFace:")
            cachedTransformAddFaceMethod = (method, selector)
            method(object, selector, face)
        }
    }
}

private var cachedTransformAddVertexMethod: (@convention(c) (AnyObject, Selector, MeshTransformMeshVertex) -> Void, Selector)?
private func invokeTransformAddVertexMethod(object: NSObject, vertex: MeshTransformMeshVertex) {
    if let cachedTransformAddVertexMethod {
        return cachedTransformAddVertexMethod.0(object, cachedTransformAddVertexMethod.1, vertex)
    } else {
        let method: (@convention(c) (AnyObject, Selector, MeshTransformMeshVertex) -> Void)? = getMethod(object: object, selector: "addVertex:")
        if let method {
            let selector = NSSelectorFromString("addVertex:")
            cachedTransformAddVertexMethod = (method, selector)
            method(object, selector, vertex)
        }
    }
}

private var cachedTransformSetSubdivisionStepsMethod: (@convention(c) (AnyObject, Selector, Int) -> Void, Selector)?
private func invokeTransformSetSubdivisionStepsMethod(object: NSObject, value: Int) {
    if let cachedTransformSetSubdivisionStepsMethod {
        return cachedTransformSetSubdivisionStepsMethod.0(object, cachedTransformSetSubdivisionStepsMethod.1, value)
    } else {
        let method: (@convention(c) (AnyObject, Selector, Int) -> Void)? = getMethod(object: object, selector: "setSubdivisionSteps:")
        if let method {
            let selector = NSSelectorFromString("setSubdivisionSteps:")
            cachedTransformSetSubdivisionStepsMethod = (method, selector)
            method(object, selector, value)
        }
    }
}

public final class MeshTransform {
    public typealias Value = NSObject
    
    public typealias Point3D = MeshTransformPoint3D
    public typealias Vertex = MeshTransformMeshVertex
    public typealias Face = MeshTransformMeshFace
    
    private var vertices: ContiguousArray<Vertex> = []
    private var faces: ContiguousArray<Face> = []
    
    public var subdivisionSteps: Int = -1 {
        didSet {
            /*if self.subdivisionSteps != oldValue, let value {
                invokeTransformSetSubdivisionStepsMethod(object: value, value: self.subdivisionSteps)
            }*/
        }
    }
    
    public init() {
    }
    
    public func add(_ vertex: Vertex) {
        /*if let value = self.value {
            invokeTransformAddVertexMethod(object: value, vertex: vertex)
        }*/
        self.vertices.append(vertex)
    }
    
    public func add(_ face: Face) {
        /*if let value = self.value {
            invokeTransformAddFaceMethod(object: value, face: face)
        }*/
        self.faces.append(face)
    }
    
    public consuming func makeValue() -> Value? {
        guard let transformClass else {
            return nil
        }
        let value = unsafeBitCast(transformClass, to: MeshTransformClass.self)
        let result = self.vertices.withUnsafeMutableBufferPointer { vertices -> NSObject? in
            return self.faces.withUnsafeMutableBufferPointer { faces -> NSObject? in
                let result = value.meshTransform(withVertexCount: UInt(vertices.count), vertices: vertices.baseAddress!, faceCount: UInt(faces.count), faces: faces.baseAddress!, depthNormalization: "none")
                return result as? NSObject
            }
        }
        if let result {
            invokeTransformSetSubdivisionStepsMethod(object: result, value: self.subdivisionSteps)
        }
        
        return result
    }
}
