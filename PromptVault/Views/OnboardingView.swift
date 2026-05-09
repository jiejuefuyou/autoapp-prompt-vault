import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasSeenOnboarding: Bool
    @State private var page = 0

    private let pages: [Page] = [
        Page(icon: "sparkles", titleKey: "Save the prompts you actually use", subtitleKey: "ChatGPT · Claude · Midjourney · ComfyUI · Coze. One vault for all of them."),
        Page(icon: "textformat.abc", titleKey: "Fill in the blanks", subtitleKey: "Use {{variables}} to template your prompts. Tap a row, fill the blanks, copy."),
        Page(icon: "lock.shield", titleKey: "Stays on your phone", subtitleKey: "No account, no network, no data collection. Your prompts never leave your device.")
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                    pageView(p).tag(idx)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page == pages.count - 1 ? LocalizedStringKey("Get started") : LocalizedStringKey("Next")) {
                if page == pages.count - 1 {
                    hasSeenOnboarding = true
                    dismiss()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
            .padding()
        }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: p.icon).font(.system(size: 88)).foregroundStyle(.tint)
            Text(p.titleKey).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text(p.subtitleKey).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer()
        }
    }

    struct Page {
        let icon: String
        let titleKey: LocalizedStringKey
        let subtitleKey: LocalizedStringKey
    }
}
