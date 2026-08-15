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

    var body: some View {
        ZStack {
            DS.Color.surface.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("HensonGo")
                        .font(DS.Typography.display)
                        .foregroundStyle(DS.Color.primary)
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
                                Image(systemName: "globe")
                            }
                            Text("Sign in with Google")
                                .font(DS.Typography.title2)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(DS.Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button))
                    }
                    .disabled(isSigningIn)

                    Text("UMD accounts only — @umd.edu or @terpmail.umd.edu")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.neutral)
                }
                .padding(.horizontal, DS.Spacing.screenH)

                Spacer()
            }
            .padding(.vertical, 24)
        }
        .onAppear {
            locationManager.requestWhenInUseAuthorizationIfNeeded()
            cameraPermission.requestIfNeeded()
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

#Preview {
    SignInScreen()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
        .environmentObject(CameraPermissionManager())
}
