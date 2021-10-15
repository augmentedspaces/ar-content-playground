//
//  ContentView.swift
//  ARContentPlayground
//
//  Created by Nien Lam on 10/13/21.
//  Copyright © 2021 Line Break, LLC. All rights reserved.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    @Published var titleText = "AR Playground"

    @Published var counter: Int = 0

    let uiSignal = PassthroughSubject<UISignal, Never>()
    
    enum UISignal {
        case reset
        case exampleButtonPress
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            // AR View.
            ARViewContainer(viewModel: viewModel)

            // Reset button.
            Button {
                viewModel.uiSignal.send(.reset)
            } label: {
                Label("Reset", systemImage: "gobackward")
                    .font(.system(.title2).weight(.medium))
                    .foregroundColor(.white)
                    .labelStyle(IconOnlyLabelStyle())
                    .frame(width: 30, height: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()

            // UI on the top row.
            HStack() {
                Text("\(viewModel.titleText) : \(viewModel.counter)")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)

            // Controls on the bottom.
            HStack() {
                // Example button.
                Button {
                    viewModel.uiSignal.send(.exampleButtonPress)
                } label: {
                    buttonIcon("chevron.right.square", color: .green)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding()
            .padding(.bottom, 10)
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }
    
    // Helper methods for rendering icon.
    func buttonIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .resizable()
            .padding(10)
            .frame(width: 44, height: 44)
            .foregroundColor(.white)
            .background(color)
            .cornerRadius(5)
    }
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var originAnchor: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()

    let rotationGestureSpeed: Float = 0.005

    // Place holder anchor.
    var simulatedAnchor: Entity!
    

    var exampleBox: Entity!
    
    var exampleUSDZModel: Entity!
    
    var audioController: AudioPlaybackController!
    

    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
        
        setupEntities()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let deltaX = touch.location(in: self).x - touch.previousLocation(in: self).x
        simulatedAnchor.orientation *= simd_quatf(angle: Float(deltaX) * rotationGestureSpeed, axis: [0,1,0])
    }

    func setupScene() {
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        
        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            self.renderLoop()
        }.store(in: &subscriptions)
        
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
    }
    

    // Process UI signals.
    func processUISignal(_ signal: ViewModel.UISignal) {
        switch signal {
        case .reset:
            print("👇 Did press reset button")
            simulatedAnchor.orientation = simd_quatf(angle: 0, axis: [0,1,0])
            viewModel.counter = 0
            
        case .exampleButtonPress:
            print("👇 Did press example button")
            viewModel.counter += 1
        
            // audioController.stop()
        }
    }


    // Setup method.
    func setupEntities() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)


        // Offset set plane origin in front and below simulator camera.
        simulatedAnchor = Entity()
        simulatedAnchor.position = [0, -0.125, 1.3]
        originAnchor.addChild(simulatedAnchor)
        

        // Add directional light.
        let directionalLight = DirectionalLight()
        directionalLight.light.intensity = 750
        directionalLight.look(at: [0,0,0], from: [1, 1.1, 1.3], relativeTo: originAnchor)
        directionalLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 0.5, depthBias: 2)
        simulatedAnchor.addChild(directionalLight)
        

        // Add checkerboard plane.
        var checkerBoardMaterial = PhysicallyBasedMaterial()
        checkerBoardMaterial.baseColor.texture = .init(try! .load(named: "checker-board.png"))
        let checkerBoardPlane = ModelEntity(mesh: .generatePlane(width: 0.5, depth: 0.5), materials: [checkerBoardMaterial])
        simulatedAnchor.addChild(checkerBoardPlane)
    

        // Add example box.
        let boxMesh       = MeshResource.generateBox(size: 0.05, cornerRadius: 0.002)
        let cyanMaterial  = SimpleMaterial(color: .cyan, isMetallic: false)
        exampleBox = ModelEntity(mesh: boxMesh, materials: [cyanMaterial])
        exampleBox.position.y = 0.05
        simulatedAnchor.addChild(exampleBox)

        
        // Play audio file.
        do {
            let resource = try AudioFileResource.load(named: "car-beep.mp3", in: nil,
                                                      inputMode: .spatial, loadingStrategy: .preload,
                                                      shouldLoop: false)

            audioController = exampleBox.prepareAudio(resource)
            audioController.play()
        } catch {
            print("Error loading audio file")
        }


        /*
        // Add spiral staircase.
        var lastBoxEntity = exampleBox
        for _ in 0..<10 {
            // Create and position new entity.
            let newEntity = exampleBox.clone(recursive: false)
            newEntity.position.x = 0.03
            newEntity.position.y = 0.03

            // Rotate on y-axis by 45 degrees.
            newEntity.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])

            // Add to last entity in tree.
            lastBoxEntity?.addChild(newEntity)
            
            // Set last entity used.
            lastBoxEntity = newEntity
        }
         */


        /*
        // Add example usdz model.
        exampleUSDZModel = try! Entity.load(named: "toy_biplane")
        simulatedAnchor.addChild(exampleUSDZModel!)
    
        for animation in exampleUSDZModel.availableAnimations {
            exampleUSDZModel.playAnimation(animation.repeat())
        }
         */
    }


    // Render loop.
    func renderLoop() {
        // Check box is not nil.
        if let box = exampleBox {
            box.orientation *= simd_quatf(angle: 0.01, axis: [1,0,0])
        }
    }
}
