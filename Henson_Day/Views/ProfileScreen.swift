// ProfileScreen.swift
// Henson_Day
//
// Shows the signed-in user's name, email, points, and events attended, plus
// a real sign-out button (calls Supabase's signOut() through AuthManager).

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var authManager: AuthManager
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surface.ignoresSafeArea()

                if appSession.isLoadingProfile && appSession.profile == nil {
                    ProgressView("Loading profile…")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DS.Spacing.section) {
                            avatarSection

                            StatsCard(profile: appSession.profile)
                                .padding(.horizontal, DS.Spacing.screenH)

                            personalInfoCard
                                .padding(.horizontal, DS.Spacing.screenH)

                            Button {
                                showSignOutAlert = true
                            } label: {
                                if isSigningOut {
                                    ProgressView()
                                } else {
                                    Text("Sign out")
                                        .font(DS.Typography.body)
                                        .foregroundStyle(DS.Color.neutral)
                                }
                            }
                            .disabled(isSigningOut)
                            .padding(.bottom, DS.Spacing.section)
                        }
                        .padding(.top, DS.Spacing.card)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Sign out of HensonGo?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    isSigningOut = true
                    Task {
                        await authManager.signOut()
                        isSigningOut = false
                    }
                }
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(DS.Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.heroCard))
                .shadow(color: DS.Color.primary.opacity(0.35), radius: 10, x: 0, y: 4)

            Text(appSession.profile?.fullName.isEmpty == false ? appSession.profile!.fullName : "Terp")
                .font(DS.Typography.title1)
                .foregroundStyle(DS.Color.campusNight)

            Text("Henson Day Explorer")
                .font(DS.Typography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(DS.Color.primary)
                .clipShape(Capsule())
        }
    }

    private var personalInfoCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.card) {
            Text("Account")
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Color.campusNight)

            VStack(spacing: 0) {
                infoRow(icon: "person.text.rectangle", label: "Name", value: appSession.profile?.fullName ?? "—")
                Divider()
                infoRow(icon: "envelope", label: "Email", value: appSession.profile?.email ?? authManager.currentUserEmail ?? "—")
            }
            .background(DS.Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.neutral)
            Spacer()
            Text(value)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Color.campusNight)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(DS.Spacing.cardPad)
    }
}

// MARK: - Stats card

private struct StatsCard: View {
    let profile: Profile?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(profile?.totalPoints ?? 0)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(DS.Color.gold)
                Text("Total Points")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.campusNight.opacity(0.6))
            }
            Spacer()
            Divider().frame(height: 40)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(profile?.eventsAttended ?? 0)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(DS.Color.primary)
                Text("Events Attended")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.campusNight.opacity(0.6))
            }
        }
        .padding(DS.Spacing.cardPad)
        .background(
            LinearGradient(
                colors: [DS.Color.primaryTint, DS.Color.Rarity.legendaryTint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .shadow(color: DS.Color.primary.opacity(0.12), radius: DS.Shadow.cardRadius, x: DS.Shadow.cardX, y: DS.Shadow.cardY)
    }
}

#Preview {
    ProfileScreen()
        .environmentObject(AppSession(authManager: AuthManager()))
        .environmentObject(AuthManager())
}
