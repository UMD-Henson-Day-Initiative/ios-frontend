// SignInScreen.swift
// Henson_Day
//
// Google-only sign-in gate. Shown whenever there's no active Supabase
// session. Camera/location permission status is shown for transparency but
// doesn't block sign-in — those matter once you're in the Map tab.

import SwiftUI

struct SignInScreen: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var cameraPermission: CameraPermissionManager
    @State private var isSigningIn = false
    @State private var showSignInOptions = false
    @State private var showOtherLoginSheet = false

    var body: some View {
        ZStack {
            DS.Color.surface.ignoresSafeArea()

            RadialGradient(
                colors: [DS.Color.goldTint, DS.Color.surface.opacity(0)],
                center: .top,
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("HensonGo")
                        .font(DS.Typography.display)
                        .foregroundStyle(DS.Color.heroGradient)
                    Text("University of Maryland\nCampus Scavenger Hunt")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Color.neutral)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 10) {
                    permissionRow(title: "Location", isGranted: locationManager.isGranted, isDenied: locationManager.isDenied, icon: "location.fill")
                    permissionRow(title: "Camera", isGranted: cameraPermission.isAuthorized, isDenied: cameraPermission.isDeniedOrRestricted, icon: "camera.fill")
                }
                .padding(.horizontal, DS.Spacing.screenH)

                if let message = authManager.lastErrorMessage {
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.screenH)
                }

                VStack(spacing: 10) {
                    if showSignInOptions {
                        Button {
                            isSigningIn = true
                            Task {
                                await authManager.signInWithGoogle()
                                isSigningIn = false
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if isSigningIn {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "graduationcap.fill")
                                }
                                Text("Sign in as UMD Student/Faculty")
                                    .font(DS.Typography.title2)
                                    .minimumScaleFactor(0.85)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(DS.Color.heroGradient)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button))
                            .shadow(color: DS.Color.gold.opacity(0.4), radius: 10, x: 0, y: 4)
                        }
                        .disabled(isSigningIn)

                        Text("UMD accounts only — @umd.edu or @terpmail.umd.edu")
                            .font(DS.Typography.label.weight(.bold))
                            .foregroundStyle(DS.Color.primary)
                            .multilineTextAlignment(.center)

                        Button {
                            showOtherLoginSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.fill")
                                Text("Sign in as Other")
                                    .font(DS.Typography.title2)
                            }
                            .foregroundStyle(DS.Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(DS.Color.goldTint)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.button)
                                    .stroke(DS.Color.gold.opacity(0.5), lineWidth: 1.5)
                            )
                        }
                        .disabled(isSigningIn)
                        .padding(.top, 4)
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showSignInOptions = true
                            }
                        } label: {
                            Text("Sign In")
                                .font(DS.Typography.title2)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(DS.Color.heroGradient)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button))
                                .shadow(color: DS.Color.gold.opacity(0.4), radius: 10, x: 0, y: 4)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.screenH)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showSignInOptions)

                Spacer()
            }
            .padding(.vertical, 24)
        }
        .onAppear {
            locationManager.requestWhenInUseAuthorizationIfNeeded()
            cameraPermission.requestIfNeeded()
        }
        .sheet(isPresented: $showOtherLoginSheet) {
            OtherSignInSheet()
        }
    }

    private func permissionRow(title: String, isGranted: Bool, isDenied: Bool, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.campusNight)
            Spacer()
            if isGranted {
                Text("Ready")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Color.statusCompleted)
            } else if isDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(DS.Typography.label)
            } else {
                Text("Pending")
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Color.neutral)
            }
        }
        .padding(.horizontal, DS.Spacing.cardPad)
        .padding(.vertical, 10)
        .background(DS.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile))
    }
}

// MARK: - Non-UMD sign-in

/// Email/password sign-in for the one account the backend allows in besides
/// UMD accounts (see `AuthManager.signInWithPassword`).
private struct OtherSignInSheet: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(DS.Color.heroGradient)
                                .frame(width: 64, height: 64)
                            Image(systemName: "person.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Text("Sign In")
                            .font(DS.Typography.title1)
                            .foregroundStyle(DS.Color.campusNight)
                        Text("For accounts outside the UMD sign-in.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.neutral)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 12) {
                        fieldContainer {
                            TextField("Email", text: $email)
                                .textContentType(.username)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }

                        fieldContainer {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { Task { await submit() } }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.screenH)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Color.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.screenH)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSigningIn {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            Text("Sign In")
                                .font(DS.Typography.title2)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(DS.Color.heroGradient)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button))
                        .shadow(color: DS.Color.gold.opacity(0.4), radius: 10, x: 0, y: 4)
                        .opacity(canSubmit ? 1 : 0.5)
                    }
                    .disabled(!canSubmit || isSigningIn)
                    .padding(.horizontal, DS.Spacing.screenH)

                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Color.primary)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func fieldContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(DS.Typography.body)
            .padding(.horizontal, DS.Spacing.cardPad)
            .padding(.vertical, 14)
            .background(DS.Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.statTile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.statTile, style: .continuous)
                    .stroke(DS.Color.gold.opacity(0.3), lineWidth: 1.5)
            )
    }

    private func submit() async {
        guard canSubmit, !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        let success = await authManager.signInWithPassword(
            email: email.trimmingCharacters(in: .whitespaces),
            password: password
        )
        isSigningIn = false
        if success {
            dismiss()
        } else {
            errorMessage = authManager.lastErrorMessage ?? "Incorrect email or password."
        }
    }
}

#Preview {
    SignInScreen()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
        .environmentObject(CameraPermissionManager())
}
