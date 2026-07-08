import SwiftUI

/// 通讯录：全部商界联系人（含助理）。点开进对应线程。
struct ContactsView: View {
    @Bindable var store: RainmakerStore

    private var allProfiles: [NPCProfile] {
        [NPCCatalog.assistant] + NPCCatalog.contacts
    }

    var body: some View {
        NavigationStack {
            List(allProfiles) { profile in
                NavigationLink {
                    RainmakerThreadView(store: store, npcID: profile.id)
                } label: {
                    HStack(spacing: 12) {
                        WAAvatar(
                            systemImage: profile.icon,
                            background: RainmakerUI.tint(for: profile.id),
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.system(size: 17))
                                .foregroundStyle(WA.textPrimary)
                            Text(profile.role)
                                .font(.system(size: 13))
                                .foregroundStyle(WA.textSecondary)
                        }
                    }
                }
                .listRowSeparatorTint(WA.separator)
            }
            .listStyle(.plain)
            .background(WA.listBg)
            .navigationTitle("通讯录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
