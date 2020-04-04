//
//  ViewController.swift
//  MetalTessellation
//
//  Created by M.Ike on 2017/01/28.
//  Copyright © 2017年 M.Ike. All rights reserved.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {
    private let defaultCameraMatrix = Matrix.lookAt(eye: float3(0, 2, 6), center: float3(), up: float3(0, 1, 0))
    
    @IBOutlet private weak var shapePanel: NSView!
    @IBOutlet private weak var shapeSegment: NSSegmentedControl!
    @IBOutlet private weak var wirePanel: NSView!
    @IBOutlet private weak var wireCheckButton: NSButton!
    @IBOutlet private weak var tessellationPanel: NSView!
    @IBOutlet private weak var tessellationButton: NSSegmentedControl!
    @IBOutlet private weak var tessellationSlider: NSSlider!
    @IBOutlet private weak var tessellationFactorLabel: NSTextField!
    @IBOutlet private weak var phongPanel: NSView!
    @IBOutlet private weak var phongSlider: NSSlider!
    @IBOutlet private weak var phongFactorLabel: NSTextField!
    @IBOutlet private weak var displacementPanel: NSView!
    @IBOutlet private weak var displacementButton: NSSegmentedControl!
    @IBOutlet private weak var displacementSlider: NSSlider!
    @IBOutlet private weak var displacementLabel: NSTextField!
    
    @IBOutlet private weak var mtkView: MTKView!
    @IBOutlet private weak var infoLabel: NSTextField!
    @IBOutlet private weak var playButton: NSButton!
    @IBOutlet private weak var zoomSlider: NSSlider!

    private var renderer: Renderer!
    private var activeMeshRenderer: TessellationMeshRenderer? = nil
    private var totalTime = TimeInterval(0)
    
    var isPlaying = false {
        didSet {
            playButton.title = isPlaying ? "■" : "▶︎"
        }
    }
    
    enum Demo {
        case demo1(Int), demo2, demo3(Int)
    }
    
    var isWireFrame = false {
        didSet {
            renderer.isWireFrame = isWireFrame
            wireCheckButton.state = isWireFrame ? .on : .off
        }
    }

    var isTessellation = false {
        didSet {
            activeMeshRenderer?.isTesselasiton = isTessellation
            tessellationButton.selectedSegment = isTessellation ? 0 : 1
            tessellationSlider.isHidden = !isTessellation
            tessellationFactorLabel.isHidden = !isTessellation
        }
    }
    
    var tessellationFactor = Float(0) {
        didSet {
            activeMeshRenderer?.edgeFactor = tessellationFactor
            activeMeshRenderer?.insideFactor = tessellationFactor
            tessellationSlider.floatValue = tessellationFactor
            tessellationFactorLabel.stringValue = String(format: "%.02f", tessellationFactor)
        }
    }
    
    var phongFactor = Float(0) {
        didSet {
            activeMeshRenderer?.phongFactor = phongFactor
            phongSlider.floatValue = phongFactor
            phongFactorLabel.stringValue = String(format: "%.02f", phongFactor)
        }
    }
    
    var displacementFactor = Float(0) {
        didSet {
            activeMeshRenderer?.displacementFactor = displacementFactor
            displacementSlider.floatValue = displacementFactor
            displacementLabel.stringValue = String(format: "%.02f", displacementFactor)
        }
    }
    
    // MARK: -
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupMetal()
        mtkView.draw()
        
        clear()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    private func checkFPS() {
        if activeMeshRenderer == nil {
            infoLabel.stringValue = ""
        } else {
            infoLabel.stringValue = String(format: "%.0f fps", 1 / renderer.drawTime)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.checkFPS()
            }
        }
    }
    
    // MARK: -
    private func setupMetal() {
        mtkView.sampleCount = 4
        mtkView.depthStencilPixelFormat = .depth32Float_stencil8
        
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColorMake(0.3, 0.3, 0.3, 1)
        
        renderer = Renderer(view: mtkView)
        renderer.cameraMatrix = defaultCameraMatrix
        renderer.preUpdate = { [weak self] renderer in
            guard let `self` = self else { return }
            guard let active = self.activeMeshRenderer else { return }

            if self.isPlaying {
                self.totalTime += renderer.deltaTime
            }

            let scale = self.zoomSlider.floatValue
            active.modelMatrix = matrix_multiply(Matrix.scale(x: scale, y: scale, z: scale),
                                                 Matrix.rotation(radians: Float(self.totalTime) * 0.5, axis: float3(0, 1, 0)))
        }
    }

    private func clear() {
        totalTime = 0
        isPlaying = false
        renderer.targets.removeAll()
        if let mesh = activeMeshRenderer {
            activeMeshRenderer = nil
            mesh.isActive = false
        }
        
        for panel in [shapePanel, wirePanel, tessellationPanel, phongPanel, displacementPanel] {
            panel?.isHidden = true
        }
    }
    
    private func startDemo(demo: Demo, isPlaying: Bool, isWireFrame: Bool, isTessellation: Bool, tessellationFactor: Float, phongFactor: Float) {
        var isPlaying = isPlaying
//        var isWireFrame = isWireFrame
//        var isTessellation = isTessellation
//        var tessellationFactor = tessellationFactor
//        var phongFactor = phongFactor
        
        totalTime = 0
        activeMeshRenderer?.isActive = false

        switch demo {
        case .demo1(let no):
            shapeSegment.selectedSegment = no
            activeMeshRenderer = renderer.targets[no] as? TessellationMeshRenderer
            isPlaying = (no != 0)
        case .demo2:
            activeMeshRenderer = renderer.targets.first as? TessellationMeshRenderer
        case .demo3(let no):
            displacementButton.selectedSegment = no
            activeMeshRenderer = renderer.targets[no] as? TessellationMeshRenderer
            displacementFactor = activeMeshRenderer?.displacementFactor ?? 0
            displacementSlider.isEnabled = (no == 0)
        }
        self.isPlaying = isPlaying
        self.isWireFrame = isWireFrame
        self.isTessellation = isTessellation
        self.tessellationFactor = tessellationFactor
        self.phongFactor = phongFactor
        activeMeshRenderer?.isActive = true
        checkFPS()
    }
    
    // MARK: - event
    @IBAction private func toggleShape(sender: NSSegmentedControl) {
        startDemo(demo: .demo1(sender.selectedSegment),
                  isPlaying: isPlaying,
                  isWireFrame: isWireFrame,
                  isTessellation: isTessellation,
                  tessellationFactor: tessellationFactor,
                  phongFactor: phongFactor)
    }
    
    @IBAction private func toggleTessellation(sender: NSSegmentedControl) {
        isTessellation = (sender.selectedSegment == 0)
    }
    
    @IBAction private func tapWireFrame(sender: NSButton) {
        isWireFrame = (sender.state != NSControl.StateValue(rawValue: 0))
    }
    
    @IBAction private func changeTessellationFactor(sender: NSSlider) {
        tessellationFactor = sender.floatValue
    }
    
    @IBAction private func changePhongFactor(sender: NSSlider) {
        phongFactor = sender.floatValue
    }
    
    @IBAction private func toggleDisplacementType(sender: NSSegmentedControl) {
        startDemo(demo: .demo3(sender.selectedSegment),
                  isPlaying: isPlaying,
                  isWireFrame: isWireFrame,
                  isTessellation: isTessellation,
                  tessellationFactor: tessellationFactor,
                  phongFactor: phongFactor)
    }
    
    @IBAction private func changeDisplacement(sender: NSSlider) {
        displacementFactor = sender.floatValue
    }

    @IBAction private func tapPlay(sender: NSButton) {
        guard activeMeshRenderer != nil else { return }
        isPlaying = !isPlaying
    }
    
    // MARK: - demo
    @IBAction private func tapDemo1(sender: NSButton) {
        clear()
        
        let triangle = GeometryMesh.meshLambert(
            shapeType: .triangle(dimensions: vector_float3(2)),
            diffuseTextureURL: Bundle.main.url(forResource: "Resources/white", withExtension: "png")!,
            setupBaseMatrix: { return $0 })
        let box = GeometryMesh.meshLambert(
            shapeType: .box(dimensions: vector_float3(1), segments: vector_uint3(1)),
            diffuseTextureURL: Bundle.main.url(forResource: "Resources/white", withExtension: "png")!,
            setupBaseMatrix: { return matrix_multiply(Matrix.scale(x: 3, y: 3, z: 3), $0) })

        for mesh in [triangle, box] {
            let meshRenderer = TessellationMeshRenderer(renderer: renderer, mesh: mesh)
            meshRenderer.displacementFactor = 0
            meshRenderer.displacementOffset = 0
            meshRenderer.phongFactor = 0
            meshRenderer.isActive = false
            renderer.targets.append(meshRenderer)
        }

        shapePanel.isHidden = false
        wirePanel.isHidden = false
        tessellationPanel.isHidden = false

        startDemo(demo: .demo1(0),
                  isPlaying: false,
                  isWireFrame: true,
                  isTessellation: false,
                  tessellationFactor: Float(tessellationSlider.minValue),
                  phongFactor: 0)
    }
    
    @IBAction private func tapDemo2(sender: NSButton) {
        clear()
       
        let sphere = GeometryMesh.meshDisplacementMap(
//            shapeType: .sphere(radii: vector_float3(1), segments: vector_uint2(32)),
            shapeType: .sphere(radii: vector_float3(1), segments: vector_uint2(6)),
            diffuseTextureURL: Bundle.main.url(forResource: "Resources/sand", withExtension: "png")!,
            normalMapURL: Bundle.main.url(forResource: "Resources/white", withExtension: "png")!,
            displacementlMapURL: Bundle.main.url(forResource: "Resources/white", withExtension: "png")!,
            setupBaseMatrix: { return matrix_multiply(Matrix.scale(x: 4, y: 4, z: 4), $0) })
        let meshRenderer = TessellationMeshRenderer(renderer: renderer, mesh: sphere)
        meshRenderer.displacementFactor = 0
        meshRenderer.displacementOffset = 0
        meshRenderer.phongFactor = 0
        meshRenderer.isActive = false
        renderer.targets.append(meshRenderer)
        
        wirePanel.isHidden = false
        tessellationPanel.isHidden = false
        phongPanel.isHidden = false
        
        startDemo(demo: .demo2,
                  isPlaying: true,
                  isWireFrame: true,
                  isTessellation: false,
                  tessellationFactor: Float(tessellationSlider.minValue),
                  phongFactor: 0)
    }

    @IBAction private func tapDemo3(sender: NSButton) {
        clear()

        let sphere = GeometryMesh.meshDisplacementMap(
            shapeType: .sphere(radii: vector_float3(1), segments: vector_uint2(16)),
            diffuseTextureURL: Bundle.main.url(forResource: "Resources/metal/diffuse", withExtension: "png")!,
            normalMapURL: Bundle.main.url(forResource: "Resources/metal/normal", withExtension: "png")!,
            displacementlMapURL: Bundle.main.url(forResource: "Resources/metal/bump", withExtension: "png")!,
            setupBaseMatrix: { return matrix_multiply(Matrix.scale(x: 4, y: 4, z: 4), $0) })
        let sphereRenderer = TessellationMeshRenderer(renderer: renderer, mesh: sphere)
        sphereRenderer.displacementFactor = 0
        sphereRenderer.displacementOffset = 0
        sphereRenderer.phongFactor = 0
        sphereRenderer.isActive = false
        renderer.targets.append(sphereRenderer)
        
        let earth = GeometryMesh.meshDisplacementMap(
            shapeType: .sphere(radii: vector_float3(1), segments: vector_uint2(16)),
            diffuseTextureURL: Bundle.main.url(forResource: "Resources/earth/diffuse", withExtension: "jpg")!,
            normalMapURL: Bundle.main.url(forResource: "Resources/earth/normal", withExtension: "jpg")!,
            displacementlMapURL: Bundle.main.url(forResource: "Resources/earth/bump", withExtension: "jpg")!,
            setupBaseMatrix: { return matrix_multiply(Matrix.scale(x: 4, y: 4, z: -4), $0) })
        let meshRenderer = TessellationMeshRenderer(renderer: renderer, mesh: earth)
        meshRenderer.displacementFactor = 0.04
        meshRenderer.displacementOffset = 0
        meshRenderer.phongFactor = 0
        meshRenderer.isActive = false
        renderer.targets.append(meshRenderer)
        
        wirePanel.isHidden = false
        tessellationPanel.isHidden = false
//        phongPanel.isHidden = false
        displacementPanel.isHidden = false
        
        startDemo(demo: .demo3(1),
                  isPlaying: true,
                  isWireFrame: false,
                  isTessellation: true,
                  tessellationFactor: Float(tessellationSlider.maxValue),
                  phongFactor: 0.5)
    }
    
    @IBAction private func tapDemoStop(sender: NSButton) {
        clear()
    }
}

