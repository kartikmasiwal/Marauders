import SwiftUI

struct AuthenticationView: View {
    @Environment(AppSession.self) private var session
    @State private var phone = "98765 43210"
    @State private var otp = ""
    @State private var step: Step = .phone
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let service = DemoAuthenticationService()

    enum Step { case phone, otp }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.surface, Theme.surfaceContainer, Theme.goldLight.opacity(0.32)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            Circle()
                .fill(Theme.primary.opacity(0.08))
                .frame(width: 330)
                .blur(radius: 2)
                .offset(x: 160, y: -330)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    brand
                    welcome
                    authenticationCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 42)
                .padding(.bottom, 30)
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image("MaraudersLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Marauders logo")
            VStack(alignment: .leading, spacing: 0) {
                Text("MARAUDERS")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(2)
                Text("STORIES IN EVERY STEP")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(Theme.gold)
            }
        }
        .foregroundStyle(Theme.primary)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step == .phone ? "Your journey starts here." : "Check your messages.")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(step == .phone ? "Unlock the stories hidden inside every monument." : "Enter the 6-digit code sent to +91 \(phone).")
                .font(.system(size: 17))
                .foregroundStyle(Theme.mutedInk)
        }
    }

    private var authenticationCard: some View {
        VStack(spacing: 18) {
            if step == .phone {
                phoneField
                Button(action: requestOTP) {
                    loadingLabel("Continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(phone.filter(\.isNumber).count < 10 || isLoading)

                divider

                Button {
                    session.signIn(phone: "Google demo account")
                } label: {
                    HStack(spacing: 12) {
                        Text("G").font(.system(size: 19, weight: .bold))
                        Text("Continue with Google").fontWeight(.semibold)
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 15).stroke(Theme.outline.opacity(0.7)) }
                }
                .accessibilityIdentifier("googleSignInButton")
            } else {
                otpField
                Text("Demo code: 123456")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.teal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: verifyOTP) {
                    loadingLabel("Verify & enter")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(otp.count != 6 || isLoading)
                .accessibilityIdentifier("verifyOTPButton")

                Button("Use a different number") {
                    withAnimation { step = .phone; otp = ""; errorMessage = nil }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            Text("By continuing, you agree to the demo Terms and Privacy Policy.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.mutedInk.opacity(0.8))
        }
        .padding(22)
        .heritageCard()
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHONE NUMBER").font(.caption.weight(.bold)).tracking(1).foregroundStyle(Theme.mutedInk)
            HStack {
                Text("+91").fontWeight(.semibold)
                Divider().frame(height: 24)
                TextField("98765 43210", text: $phone)
                    .keyboardType(.phonePad)
                    .accessibilityIdentifier("phoneField")
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Theme.surfaceLow, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.outline.opacity(0.55)) }
        }
    }

    private var otpField: some View {
        TextField("123456", text: $otp)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .tracking(10)
            .padding(.leading, 10)
            .frame(height: 60)
            .background(Theme.surfaceLow, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.outline.opacity(0.55)) }
            .onChange(of: otp) { _, value in otp = String(value.filter(\.isNumber).prefix(6)) }
            .accessibilityIdentifier("otpField")
    }

    private var divider: some View {
        HStack { Rectangle().frame(height: 1); Text("OR").font(.caption.weight(.semibold)); Rectangle().frame(height: 1) }
            .foregroundStyle(Theme.outline)
    }

    private func loadingLabel(_ text: String) -> some View {
        HStack { if isLoading { ProgressView().tint(.white) }; Text(text) }
    }

    private func requestOTP() {
        isLoading = true
        Task {
            try? await service.requestOTP(for: phone)
            isLoading = false
            withAnimation { step = .otp }
        }
    }

    private func verifyOTP() {
        isLoading = true
        Task {
            let valid = (try? await service.verify(otp: otp)) ?? false
            isLoading = false
            if valid { session.signIn(phone: phone) } else { errorMessage = "That code is not valid. Try 123456." }
        }
    }
}
