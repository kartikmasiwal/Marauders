import ARKit
import AVFoundation
import SwiftUI
import UIKit

struct ARCameraView: View {
    @ObservedObject var session: TourSession
    @ObservedObject var audioPlayer: NuggetAudioPlayer
    @StateObject private var question = VoiceQuestionService()
    @State private var cameraAuthorized: Bool?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if !ARImageTrackingConfiguration.isSupported {
                simulatorFallback
            } else if cameraAuthorized == true {
                ARImageTrackingView(session: session, onFound: found, onLost: lost)
                    .ignoresSafeArea()
            } else if cameraAuthorized == false {
                cameraDenied
            } else {
                ProgressView("Preparing AR camera…").tint(.white).foregroundStyle(.white)
            }
            if cameraAuthorized != false { cameraOverlay }
        }
        .task { await requestCameraAccess() }
    }

    private var cameraOverlay: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE AR").font(.caption.bold()).tracking(1.3).foregroundStyle(Theme.goldLight)
                    Text(session.currentCheckpoint?.name.v(session.language) ?? session.installed.package.monument.name.v(session.language))
                        .font(.headline).foregroundStyle(.white)
                }
                Spacer()
                Label(session.language.uppercased(), systemImage: "globe")
                    .font(.caption.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule())
            }
            .padding(20)

            Spacer()

            if let nugget = session.activeNugget {
                VStack(spacing: 7) {
                    if nugget.exclusive { Text("★ GUIDE EXCLUSIVE").font(.caption2.bold()).tracking(1).foregroundStyle(Theme.goldLight) }
                    Text(nugget.title.v(session.language)).font(.title2.bold()).foregroundStyle(.white).multilineTextAlignment(.center)
                    Text(audioStatus).font(.caption).foregroundStyle(.white.opacity(0.75))
                }
                .padding(18).frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 20)
            } else {
                Text("Hold a printed target steady to reveal its story")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12).background(.ultraThinMaterial, in: Capsule())
            }

            questionStatus

            Button {
                guard let checkpoint = session.currentCheckpoint else { return }
                audioPlayer.stop()
                question.toggleRecording(
                    checkpointID: checkpoint.id,
                    monumentID: session.installed.package.monument.id,
                    language: session.language
                )
            } label: {
                Image(systemName: question.state == .recording ? "stop.fill" : "mic.fill")
                    .font(.title2).foregroundStyle(question.state == .recording ? Theme.primary : .white)
                    .frame(width: 72, height: 72)
                    .background(question.state == .recording ? Color.white : Theme.primary, in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 4).padding(5) }
            }
            .accessibilityIdentifier("liveQuestionButton")
            .padding(.top, 12).padding(.bottom, 106)
        }
        .background(LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom))
    }

    @ViewBuilder
    private var questionStatus: some View {
        switch question.state {
        case .recording:
            Text("Listening… Tap to send").statusPill(color: .red)
        case .thinking:
            Label("Guide is thinking…", systemImage: "ellipsis.bubble").statusPill(color: Theme.gold)
        case .speaking:
            Text(question.answerText ?? "Answering…").statusPill(color: Theme.teal)
        case .failed(let message):
            Button {
                guard let checkpoint = session.currentCheckpoint else { return }
                question.retry(checkpointID: checkpoint.id, monumentID: session.installed.package.monument.id, language: session.language)
            } label: {
                Label(message + " Tap to retry.", systemImage: "arrow.clockwise").statusPill(color: Theme.primary)
            }
        case .idle:
            EmptyView()
        }
    }

    private var simulatorFallback: some View {
        VStack(spacing: 18) {
            Image(systemName: "arkit").font(.system(size: 52)).foregroundStyle(Theme.goldLight)
            Text("AR target simulator").font(.title2.bold()).foregroundStyle(.white)
            Text("Select a target below. Use a physical iPhone for image tracking.").foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(session.installed.package.checkpoints) { checkpoint in
                        ForEach(checkpoint.nuggets) { nugget in
                            Button { found(checkpoint, nugget) } label: {
                                HStack { Text(nugget.title.v(session.language)); Spacer(); Image(systemName: "viewfinder") }
                                    .padding(14).foregroundStyle(Theme.ink).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }.frame(maxHeight: 280)
        }.padding(28).padding(.bottom, 120)
    }

    private var cameraDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.system(size: 48)).foregroundStyle(Theme.goldLight)
            Text("Camera access is needed").font(.title2.bold()).foregroundStyle(.white)
            Text("Enable camera access to recognize the printed monument targets.")
                .foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 260)
        }.padding(30).padding(.bottom, 100)
    }

    private var audioStatus: String {
        switch audioPlayer.state {
        case .entering: "Target locked · preparing story"
        case .playing: "Playing local audio"
        case .exiting: "Keep the target in view"
        case .idle: "Ready"
        }
    }

    private func found(_ checkpoint: Checkpoint, _ nugget: Nugget) {
        session.select(checkpoint: checkpoint, nugget: nugget)
        audioPlayer.targetFound(nugget: nugget, language: session.language, directory: session.installed.directory)
    }

    private func lost(_ nugget: Nugget) { audioPlayer.targetLost(nuggetID: nugget.id) }

    private func requestCameraAccess() async {
        guard ARImageTrackingConfiguration.isSupported else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraAuthorized = true
        case .notDetermined: cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted: cameraAuthorized = false
        @unknown default: cameraAuthorized = false
        }
    }
}

private extension View {
    func statusPill(color: Color) -> some View {
        self.font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(3)
            .padding(.horizontal, 14).padding(.vertical, 9).background(color.opacity(0.88), in: Capsule()).padding(.top, 10)
    }
}
