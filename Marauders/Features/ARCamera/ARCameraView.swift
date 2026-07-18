import SwiftUI
import UIKit

struct ARCameraView: View {
    let monument: Monument
    @StateObject private var camera = CameraService()
    @State private var showGuide = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera.state {
            case .checking:
                ProgressView("Preparing camera…").tint(.white).foregroundStyle(.white)
            case .denied:
                permissionView
            case .unavailable:
                unavailableView
            case .ready:
                cameraExperience
            }
        }
        .onAppear { camera.requestAccessAndConfigure() }
        .onDisappear { camera.stop() }
    }

    private var cameraExperience: some View {
        ZStack {
            CameraPreview(session: camera.session).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            if showGuide {
                RoundedRectangle(cornerRadius: 36)
                    .stroke(Theme.goldLight.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [12, 9]))
                    .frame(width: 260, height: 330)
                    .overlay(alignment: .top) {
                        Text("ALIGN A MONUMENT DETAIL")
                            .font(.caption2.bold()).tracking(1.2).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7).background(.black.opacity(0.55), in: Capsule()).offset(y: -16)
                    }
            }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LIVE AR").font(.caption.bold()).tracking(1.3).foregroundStyle(Theme.goldLight)
                        Text(monument.name).font(.headline).foregroundStyle(.white)
                    }
                    Spacer()
                    Button { showGuide.toggle() } label: {
                        Image(systemName: showGuide ? "square.dashed" : "square.dashed.inset.filled")
                            .font(.title3).foregroundStyle(.white).frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
                    }
                }.padding(.horizontal, 20).padding(.top, 16)
                Spacer()
                HStack {
                    if let image = camera.capturedImage {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 2) }
                    } else {
                        Color.clear.frame(width: 52, height: 52)
                    }
                    Spacer()
                    Button(action: camera.capture) {
                        Circle().fill(.white.opacity(0.3)).frame(width: 78, height: 78)
                            .overlay { Circle().stroke(.white, lineWidth: 4).padding(5) }
                            .overlay { Image(systemName: "viewfinder").foregroundStyle(.white).font(.title2) }
                    }.accessibilityIdentifier("cameraCaptureButton")
                    Spacer()
                    Image(systemName: "arkit").font(.title2).foregroundStyle(.white).frame(width: 52, height: 52).background(.ultraThinMaterial, in: Circle())
                }.padding(.horizontal, 28).padding(.bottom, 105)
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill").font(.system(size: 48)).foregroundStyle(Theme.goldLight)
            Text("Camera access is needed").font(.title2.bold()).foregroundStyle(.white)
            Text("Marauders keeps the camera inside the app to layer tour content over the monument around you.")
                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 280)
        }.padding(30)
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "iphone.gen3.slash").font(.system(size: 48)).foregroundStyle(Theme.goldLight)
            Text("Camera unavailable").font(.title2.bold()).foregroundStyle(.white)
            Text("Use a physical iPhone to preview the in-app AR camera experience.").foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
        }.padding(30)
    }
}
