//
//  TessellationMeshRenderer.swift
//  MetalTessellation
//
//  Created by M.Ike on 2017/01/29.
//  Copyright © 2017年 M.Ike. All rights reserved.
//

import Foundation
import MetalKit

class TessellationMeshRenderer: RenderObject {
    let triangleVertex = 3
    
    struct TessellationUniforms {
        var phongFactor: Float
        var displacementFactor: Float
        var displacementOffset: Float
    }
    
    private let tessellationFactorsBuffer: MTLBuffer
    private let tessellationUniformsBuffer: MTLBuffer
    
    var edgeFactor = UInt16(2)
    var insideFactor = UInt16(2)
    
    var phongFactor = Float(0) {
        didSet { updateUniforms() }
    }
    var displacementFactor = Float(0) {
        didSet { updateUniforms() }
    }
    var displacementOffset = Float(0) {
        didSet { updateUniforms() }
    }
    
    private let computePipeline: MTLComputePipelineState
    
    // MARK: - Common
    var name = "TessellationRenderer"
    let renderState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    
    var vertexBuffer: MTLBuffer
    let vertexTexture: MTLTexture?
    let fragmentTexture: MTLTexture?
    
    var isActive = true
    var modelMatrix = matrix_identity_float4x4
    
    private let vertexCount: Int
    
    init(renderer: Renderer) {
        let device = renderer.device
        let library = renderer.library
        let mtkView = renderer.view!
        

        let asset = MDLAsset(url: Bundle.main.url(forResource: "a", withExtension: "obj")!,
                             vertexDescriptor: MTKModelIOVertexDescriptorFromMetal(Renderer.Vertex.vertexDescriptor()),
                             bufferAllocator: MTKMeshBufferAllocator(device: device))

        // 0決め打ち
        var mdlArray: NSArray?
        let mtkMeshes = try! MTKMesh.newMeshes(from: asset, device: device, sourceMeshes: &mdlArray)
        let mesh = mtkMeshes[0]
        
        let mdl = mdlArray![0] as! MDLMesh
//        let diff = mdl.boundingBox.maxBounds - mdl.boundingBox.minBounds
//        let scale = 1.0 / max(diff.x, max(diff.y, diff.z))
//        let center = (mdl.boundingBox.maxBounds + mdl.boundingBox.minBounds) / vector_float3(2)
//        let normalizeMatrix = matrix_multiply(matrix4x4_scale(scale, scale, scale),
//                                              matrix4x4_translation(-center.x, -center.y, -center.z))
//        
//        modelMatrix = matrix_multiply(matrix4x4_scale(2, 2, 2), normalizeMatrix)
        
//        let mdlMesh = MDLMesh(sphereWithExtent: vector_float3(2, 2, 2),
//                              segments: vector_uint2(8, 8),
//                              inwardNormals: false,
//                              geometryType: .triangles,
//                              allocator: MTKMeshBufferAllocator(device: device))
//        let mdlMesh = MDLMesh.newBox(withDimensions: vector_float3(2, 2, 2),
//                                     segments: vector_uint3(1, 1, 1),
//                                     geometryType: .triangles,
//                                     inwardNormals: false,
//                                     allocator: MTKMeshBufferAllocator(device: device))
        
        let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
        
        print(vertexDescriptor.attributes[0].offset)
        print(vertexDescriptor.attributes[0].format.rawValue)
        print(vertexDescriptor.attributes[1].offset)
        print(vertexDescriptor.attributes[1].format.rawValue)
        print(vertexDescriptor.attributes[2].offset)
        print(vertexDescriptor.attributes[2].format.rawValue)
        print(vertexDescriptor.attributes[3].offset)
        print(vertexDescriptor.attributes[3].format.rawValue)
        print(vertexDescriptor.layouts[0].stride)
        
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.vertexDescriptor = vertexDescriptor
        renderDescriptor.sampleCount = mtkView.sampleCount
        renderDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        renderDescriptor.vertexFunction = library.makeFunction(name: "tessellationTriangleVertex")
        renderDescriptor.fragmentFunction = library.makeFunction(name: "lambertFragment")
        renderDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        renderDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        renderDescriptor.isTessellationFactorScaleEnabled = false
        renderDescriptor.tessellationFactorFormat = .half
        renderDescriptor.tessellationControlPointIndexType = .none
        renderDescriptor.tessellationFactorStepFunction = .constant
        renderDescriptor.tessellationOutputWindingOrder = .clockwise
        renderDescriptor.tessellationPartitionMode = .fractionalEven
        renderDescriptor.maxTessellationFactor = 16
        
        self.renderState = try! device.makeRenderPipelineState(descriptor: renderDescriptor)
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        self.depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        let loader = MTKTextureLoader(device: device)
        self.vertexTexture = try! loader.newTexture(withContentsOf: Bundle.main.url(forResource: "checkerboard",
                                                                                    withExtension: "png")!,
                                                    options: nil)
        self.fragmentTexture = try! loader.newTexture(withContentsOf: Bundle.main.url(forResource: "checkerboard",
                                                                                      withExtension: "png")!,
                                                      options: nil)
        
        self.tessellationFactorsBuffer = device.makeBuffer(length: MemoryLayout<uint2>.stride,
                                                           options: .storageModePrivate)
        tessellationFactorsBuffer.label = "Tessellation Factors"
        self.tessellationUniformsBuffer = device.makeBuffer(length: MemoryLayout<TessellationUniforms>.stride,
                                                            options: .storageModeShared)
        tessellationUniformsBuffer.label = "Tessellation Uniforms"
        
        let count = vertexDescriptor.layouts[0].stride / MemoryLayout<Float>.stride
        let pVertex = mesh.vertexBuffers[0].buffer.contents().assumingMemoryBound(to: Float.self)
        let data = UnsafeBufferPointer(start: pVertex, count: mesh.vertexCount * count).map { $0 }
        let subMesh = mesh.submeshes[0]
        let pIndex = subMesh.indexBuffer.buffer.contents().assumingMemoryBound(to: UInt16.self)
        let index = UnsafeBufferPointer(start: pIndex, count: subMesh.indexCount).map { $0 }

        var points = [Float]()
        index.forEach {
            let i = Int($0) * count
            points.append(contentsOf: data[i..<(i + count)])
        }

        vertexCount = index.count
        self.vertexBuffer = device.makeBuffer(bytes: &points, length: MemoryLayout<Float>.stride * points.count, options: [])
        
        let kernel = library.makeFunction(name: "tessellationFactorsCompute")
        computePipeline = try! device.makeComputePipelineState(function: kernel!)
        
        updateUniforms()
    }
    
    func compute(renderer: Renderer, commandBuffer: MTLCommandBuffer) {
        let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        computeCommandEncoder.label = "Compute Tessellation Factors"
        computeCommandEncoder.pushDebugGroup("Compute Tessellation Factors")
        
        computeCommandEncoder.setComputePipelineState(computePipeline)
        
        var factor = uint2(UInt32(edgeFactor), UInt32(insideFactor))
        withUnsafePointer(to: &factor) {
            computeCommandEncoder.setBytes(UnsafeRawPointer($0), length: MemoryLayout<uint2>.stride, at: 0)
        }
        
        computeCommandEncoder.setBuffer(tessellationFactorsBuffer, offset: 0, at: 1)
        computeCommandEncoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
                                                   threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        
        computeCommandEncoder.popDebugGroup()
        computeCommandEncoder.endEncoding()
    }
    
    func update(renderer: Renderer) {
        modelMatrix = Matrix.rotation(radians: Float(renderer.totalTime) * 0.5, axis: float3(0, 1, 0))
    }
    
    func render(renderer: Renderer, encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(tessellationUniformsBuffer, offset: 0, at: 2)
        encoder.setTessellationFactorBuffer(tessellationFactorsBuffer, offset: 0, instanceStride: 0)
        encoder.drawPatches(numberOfPatchControlPoints: triangleVertex,
                            patchStart: 0,
                            patchCount: vertexCount / triangleVertex,
                            patchIndexBuffer: nil,
                            patchIndexBufferOffset: 0,
                            instanceCount: 1,
                            baseInstance: 0)
    }
    
    // MARK: -
    private func updateUniforms() {
        let p = tessellationUniformsBuffer.contents().assumingMemoryBound(to: TessellationUniforms.self)
        p.pointee.phongFactor = phongFactor
        p.pointee.displacementFactor = displacementFactor
        p.pointee.displacementOffset = displacementOffset
    }
}