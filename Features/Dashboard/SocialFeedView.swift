import SwiftUI

// MARK: - Models (Mocked for Demo)
struct FriendActivity: Identifiable {
    let id = UUID()
    let name: String
    let avatarName: String // System image or asset name
    let actionText: String
    let timeAgo: String
    var kudosCount: Int
    var hasGivenKudos: Bool = false
}

class BuddyManager: ObservableObject {
    @Published var feed: [FriendActivity] = [
        FriendActivity(name: "Lukáš", avatarName: "person.crop.circle.fill", actionText: "zničil záda, zvedl 12 tun!", timeAgo: "Před 2 hodinami", kudosCount: 5),
        FriendActivity(name: "Tomáš", avatarName: "person.crop.circle.dashed", actionText: "dokončil těžký trénink Nohy (Squat PR 140kg).", timeAgo: "Včera", kudosCount: 12),
        FriendActivity(name: "Klára", avatarName: "person.crop.circle.badge.checkmark", actionText: "jela ranní HIIT a spálila 600 kalorií.", timeAgo: "Dnes ráno", kudosCount: 8)
    ]
    
    // Zde by byla integrace se Supabase:
    // func fetchFeed() async {
    //      let data = await supabase.from("social_activities").select().execute()
    //      ...
    // }
    
    func giveKudos(to activityId: UUID) {
        if let index = feed.firstIndex(where: { $0.id == activityId }) {
            if !feed[index].hasGivenKudos {
                feed[index].kudosCount += 1
                feed[index].hasGivenKudos = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                
                // Supabase Sync:
                // Task { await supabase.from("kudos").insert(["activity_id": activityId, "user_id": myId]).execute() }
            }
        }
    }
}

struct SocialFeedView: View {
    @StateObject private var buddyManager = BuddyManager()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Aktivita přátel")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                VStack(spacing: 16) {
                    ForEach(buddyManager.feed) { activity in
                        SocialFeedRow(activity: activity) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                buddyManager.giveKudos(to: activity.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}

struct SocialFeedRow: View {
    let activity: FriendActivity
    let onKudos: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profilovka
            Image(systemName: activity.avatarName)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .foregroundStyle(.white.opacity(0.8))
                .background(Circle().fill(Color.blue.opacity(0.2)))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                // Text
                (Text(activity.name).fontWeight(.bold).foregroundStyle(.white) +
                 Text(" ") +
                 Text(activity.actionText).foregroundStyle(.white.opacity(0.8)))
                    .font(.system(size: 15))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Čas
                Text(activity.timeAgo)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                
                // Tlačítka
                HStack(spacing: 16) {
                    Button(action: onKudos) {
                        HStack(spacing: 6) {
                            Image(systemName: activity.hasGivenKudos ? "flame.fill" : "flame")
                                .foregroundStyle(activity.hasGivenKudos ? .red : .white.opacity(0.5))
                                .font(.system(size: 14))
                            
                            Text("\(activity.kudosCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(activity.hasGivenKudos ? .red : .white.opacity(0.5))
                                .contentTransition(.numericText())
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(activity.hasGivenKudos ? Color.red.opacity(0.15) : Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
}

#Preview {
    SocialFeedView()
        .preferredColorScheme(.dark)
}
