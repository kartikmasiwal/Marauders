import ARKit
import SwiftUI

struct ARImageTrackingView: UIViewRepresentable {
    let session: TourSession
    let onFound: (Checkpoint, Nugget) -> Void
    let onLost: (Nugget) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        context.coordinator.run(on: view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        private let parent: ARImageTrackingView
        private var nuggetByTarget: [String: (Checkpoint, Nugget)] = [:]
        private var trackedTargets = Set<String>()

        init(parent: ARImageTrackingView) {
            self.parent = parent
            super.init()
            for checkpoint in parent.session.installed.package.checkpoints {
                for nugget in checkpoint.nuggets { nuggetByTarget[nugget.targetImageId] = (checkpoint, nugget) }
            }
        }

        func run(on view: ARSCNView) {
            let references = Set(nuggetByTarget.compactMap { targetID, value -> ARReferenceImage? in
                let url = parent.session.installed.targetURL(for: value.1)
                guard let image = UIImage(contentsOfFile: url.path)?.cgImage else { return nil }
                let reference = ARReferenceImage(image, orientation: .up, physicalWidth: 0.18)
                reference.name = targetID
                return reference
            })
            guard !references.isEmpty else { return }
            let configuration = ARImageTrackingConfiguration()
            configuration.trackingImages = references
            configuration.maximumNumberOfTrackedImages = min(references.count, 4)
            view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARImageAnchor else { return nil }
            let node = SCNNode()
            let plane = SCNPlane(width: 0.2, height: 0.2)
            plane.cornerRadius = 0.025
            plane.firstMaterial?.diffuse.contents = UIColor(Theme.primary).withAlphaComponent(0.18)
            plane.firstMaterial?.emission.contents = UIColor(Theme.goldLight).withAlphaComponent(0.55)
            let glow = SCNNode(geometry: plane)
            glow.eulerAngles.x = -.pi / 2
            glow.position.y = 0.002
            node.addChildNode(glow)
            return node
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for case let anchor as ARImageAnchor in anchors {
                guard let name = anchor.referenceImage.name, let value = nuggetByTarget[name] else { continue }
                if anchor.isTracked, trackedTargets.insert(name).inserted {
                    Task { @MainActor in self.parent.onFound(value.0, value.1) }
                } else if !anchor.isTracked, trackedTargets.remove(name) != nil {
                    Task { @MainActor in self.parent.onLost(value.1) }
                }
            }
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            self.session(session, didUpdate: anchors)
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for case let anchor as ARImageAnchor in anchors {
                guard let name = anchor.referenceImage.name,
                      trackedTargets.remove(name) != nil,
                      let nugget = nuggetByTarget[name]?.1 else { continue }
                Task { @MainActor in self.parent.onLost(nugget) }
            }
        }
    }
}
