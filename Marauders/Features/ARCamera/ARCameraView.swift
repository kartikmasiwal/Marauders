import ARKit
import AVFoundation
import SwiftUI
import UIKit

struct ARCameraView: View {
    @ObservedObject var session: TourSession
    @ObservedObject var audioPlayer: NuggetAudioPlayer
    @ObservedObject var ambientPlayer: AmbientAudioPlayer
    let routeChapterName: String?
    let routeTargetID: String?
    let onBrowse: () -> Void
    @StateObject private var question = VoiceQuestionService()
    @State private var cameraAuthorized: Bool?
    @State private var arFailed = false
    @State private var revealedNugget: Nugget?
    @State private var frozenFrame: UIImage?
    @State private var shutterFlash = false

    private var arReady: Bool {
        ARImageTrackingConfiguration.isSupported && cameraAuthorized == true && !arFailed
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            cameraLayer

            if let nugget = revealedNugget {
                NuggetRevealCard(
                    session: session,
                    nugget: nugget,
                    audioPlayer: audioPlayer,
                    onReplay: { audioPlayer.replay(nugget: nugget, language: session.language, directory: session.installed.directory) },
                    onClose: { withAnimation(.snappy) { revealedNugget = nil } }
                )
                .transition(.opacity)
                .zIndex(2)
            } else if arReady {
                cameraOverlay.zIndex(1)
            }

            if shutterFlash { shutterFeedback.zIndex(5) }
        }
        .task { await requestCameraAccess() }
        .onChange(of: question.suppressesTourAudio) { _, suppressed in
            ambientPlayer.setDucked(suppressed, for: .liveQuestion)
        }
        .onDisappear {
            question.cancel()
            ambientPlayer.setDucked(false, for: .liveQuestion)
        }
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if !ARImageTrackingConfiguration.isSupported {
            browseFallback(title: "AR is unavailable", message: "All package stories remain available in Audio Exp. Return to the map to complete chapters.")
        } else if cameraAuthorized == true, !arFailed {
            ARImageTrackingView(
                session: session,
                isSuppressed: question.suppressesTourAudio,
                allowedTargetIDs: routeTargetID.map { Set([$0]) },
                onFound: found,
                onLost: lost,
                onFailure: { arFailed = true }
            )
            .ignoresSafeArea()
            .clipShape(RoundedRectangle(cornerRadius: revealedNugget == nil ? 0 : 90, style: .continuous))
            .scaleEffect(revealedNugget == nil ? 1 : 0.25, anchor: .topTrailing)
            .offset(x: revealedNugget == nil ? 0 : -16, y: revealedNugget == nil ? 0 : 64)
            .allowsHitTesting(revealedNugget == nil)
            .shadow(color: .black.opacity(revealedNugget == nil ? 0 : 0.32), radius: 14)
            .animation(.snappy, value: revealedNugget?.id)
            .zIndex(revealedNugget == nil ? 0 : 4)
        } else if cameraAuthorized == false {
            browseFallback(title: "Camera access is off", message: "All package stories remain available in Audio Exp. Return to the map to complete chapters.", showsSettings: true)
        } else if arFailed {
            browseFallback(title: "AR could not start", message: "Continue with package stories in Audio Exp, then return to the map to complete this chapter.")
        } else {
            ProgressView("Preparing AR camera…").tint(.white).foregroundStyle(.white)
        }
    }

    private var cameraOverlay: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE AR").font(.caption.bold()).tracking(1.3).foregroundStyle(Theme.goldLight)
                    Text(routeChapterName ?? session.currentCheckpoint?.name.v(session.language) ?? session.installed.package.monument.name.v(session.language))
                        .font(.headline).foregroundStyle(.white)
                }
                Spacer()
                Button(action: onBrowse) {
                    Label("Audio Exp", systemImage: "headphones")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9).background(.ultraThinMaterial, in: Capsule())
                }.accessibilityIdentifier("cameraBrowseButton")
            }.padding(20)

            Spacer()
            Text("Hold a printed target steady to reveal its story")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12).background(.ultraThinMaterial, in: Capsule())

            questionStatus
            questionButton.padding(.top, 12).padding(.bottom, 106)
        }
        .background(LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom))
    }

    private var questionButton: some View {
        Button {
            guard let checkpoint = session.currentCheckpoint else { return }
            audioPlayer.stop()
            ambientPlayer.setDucked(true, for: .liveQuestion)
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
        .disabled(question.state == .thinking || question.state == .speaking || question.state == .requestingPermission)
        .opacity(question.state == .thinking || question.state == .speaking ? 0.55 : 1)
        .accessibilityIdentifier("liveQuestionButton")
    }

    @ViewBuilder
    private var questionStatus: some View {
        switch question.state {
        case .requestingPermission:
            Text("Preparing microphone…").statusPill(color: Theme.gold)
        case .recording:
            Text("Listening… Tap to send").statusPill(color: .red)
        case .thinking:
            Label("Guide is thinking…", systemImage: "ellipsis.bubble").statusPill(color: Theme.gold)
        case .speaking:
            Text(question.answerText ?? "Answering…").statusPill(color: Theme.teal)
        case .failed(let message):
            Button {
                guard let checkpoint = session.currentCheckpoint else { return }
                audioPlayer.stop()
                ambientPlayer.setDucked(true, for: .liveQuestion)
                question.retry(checkpointID: checkpoint.id, monumentID: session.installed.package.monument.id, language: session.language)
            } label: {
                Label(message + " Tap to retry.", systemImage: "arrow.clockwise").statusPill(color: Theme.primary)
            }
        case .idle:
            EmptyView()
        }
    }

    private var shutterFeedback: some View {
        ZStack {
            if let frozenFrame {
                Image(uiImage: frozenFrame).resizable().scaledToFill().ignoresSafeArea()
            }
            Color.white.opacity(0.88).ignoresSafeArea()
        }.allowsHitTesting(false)
    }

    private func browseFallback(title: String, message: String, showsSettings: Bool = false) -> some View {
        VStack(spacing: 17) {
            Image(systemName: "headphones").font(.system(size: 48)).foregroundStyle(Theme.goldLight)
            Text(title).font(.title2.bold()).foregroundStyle(.white)
            Text(message).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            Button("Open Audio Exp", action: onBrowse)
                .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 280).accessibilityIdentifier("fallbackBrowseButton")
            if showsSettings {
                Button("Open Camera Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.foregroundStyle(.white)
            }
        }.padding(30).padding(.bottom, 100)
    }

    private func found(_ checkpoint: Checkpoint, _ nugget: Nugget, _ frame: UIImage?) {
        guard !question.suppressesTourAudio else { return }
        session.select(checkpoint: checkpoint, nugget: nugget)
        audioPlayer.targetFound(nugget: nugget, language: session.language, directory: session.installed.directory)
        guard revealedNugget?.id != nugget.id else { return }
        frozenFrame = frame
        shutterFlash = true
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            shutterFlash = false
            withAnimation(.easeInOut(duration: 0.3)) { revealedNugget = nugget }
            frozenFrame = nil
        }
    }

    private func lost(_ nugget: Nugget) {
        guard !question.suppressesTourAudio else { return }
        audioPlayer.targetLost(nuggetID: nugget.id)
    }

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
