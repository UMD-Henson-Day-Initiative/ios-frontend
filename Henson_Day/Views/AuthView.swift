import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authController: AuthController
    @State private var email = ""

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !authController.isLoading
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DS.Color.surface,
                    DS.Color.primaryTint.opacity(0.8),
                    DS.Color.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Henson Day")
                            .font(DS.Typography.display)
                            .foregroundStyle(DS.Color.campusNight)

                        Text("Sign in with a secure magic link")
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Color.neutral)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Email")
                            .font(DS.Typography.label)
                            .foregroundStyle(DS.Color.campusNight)

                        TextField("you@umd.edu", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(DS.Color.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
                    }

                    Button {
                        Task { await authController.signInWithMagicLink(email: email) }
                    } label: {
                        HStack {
                            if authController.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(authController.isLoading ? "Sending link..." : "Send Magic Link")
                                .font(DS.Typography.title2)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(canSubmit ? DS.Color.primary : DS.Color.neutral.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous))
                    .disabled(!canSubmit)

                    if let infoMessage = authController.infoMessage, !infoMessage.isEmpty {
                        Text(infoMessage)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.green)
                    }

                    if let errorMessage = authController.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.red)
                    }

                    if let configurationError = authController.configurationError {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Supabase setup needed", systemImage: "exclamationmark.triangle.fill")
                                .font(DS.Typography.label)
                                .foregroundStyle(.orange)

                            Text(configurationError)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Color.neutral)

                            Text("Add SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in your app config.")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Color.neutral)
                        }
                        .padding(14)
                        .background(DS.Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
                    }
                }
                .padding(22)
                .background(DS.Color.surfaceElevated.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
                .padding(.horizontal, DS.Spacing.screenH)
                .padding(.top, 70)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthController())
}