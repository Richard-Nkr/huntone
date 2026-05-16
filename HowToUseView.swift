import SwiftUI

// MARK: - Tutorial Step Model

struct TutorialStep: Identifiable {
    let id = UUID()
    let icon: String
    let colorHex: String
    let titleKey: LocalizedStringKey
    let bodyKey: LocalizedStringKey
}

// MARK: - HowToUseView

struct HowToUseView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var currentPage = 0

    private let steps: [TutorialStep] = [
        TutorialStep(
            icon: "paintpalette.fill",
            colorHex: "#2667FF",
            titleKey: "tutorial.step1_title",
            bodyKey: "tutorial.step1_body"
        ),
        TutorialStep(
            icon: "square.grid.3x3.fill",
            colorHex: "#5B8C5A",
            titleKey: "tutorial.step2_title",
            bodyKey: "tutorial.step2_body"
        ),
        TutorialStep(
            icon: "camera.fill",
            colorHex: "#C86B4A",
            titleKey: "tutorial.step3_title",
            bodyKey: "tutorial.step3_body"
        ),
        TutorialStep(
            icon: "person.2.fill",
            colorHex: "#8B5CF6",
            titleKey: "tutorial.step4_title",
            bodyKey: "tutorial.step4_body"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Skip button (except on last page)
            HStack {
                Spacer()
                if currentPage < steps.count - 1 {
                    Button(loc("tutorial.skip")) {
                        skip()
                    }
                    .font(.custom("ClashDisplay-Medium", size: 13))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }

            Spacer()

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    tutorialPage(step)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            Spacer()

            // Bottom area: dots + button
            VStack(spacing: 24) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.black : Color(UIColor.systemGray4))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                // Action button
                Button {
                    if currentPage < steps.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        skip()
                    }
                } label: {
                    Text(currentPage < steps.count - 1
                         ? loc("tutorial.next")
                         : loc("tutorial.start"))
                        .font(.custom("ClashDisplay-Bold", size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
        .background(Color.white.ignoresSafeArea())
    }

    // MARK: - Page View

    private func tutorialPage(_ step: TutorialStep) -> some View {
        VStack(alignment: .center, spacing: 0) {
            // Icon in a colored circle
            ZStack {
                Circle()
                    .fill(Color(uiColor: UIColor(hex: step.colorHex)).opacity(0.12))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color(uiColor: UIColor(hex: step.colorHex)).opacity(0.18))
                    .frame(width: 100, height: 100)

                Image(systemName: step.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(Color(uiColor: UIColor(hex: step.colorHex)))
            }

            // Title
            Text(step.titleKey)
                .font(.custom("ClashDisplay-Bold", size: 24))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 40)
                .padding(.horizontal, 32)

            // Body
            Text(step.bodyKey)
                .font(.custom("ClashDisplay-Regular", size: 15))
                .foregroundColor(Color(UIColor.systemGray))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 16)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Actions

    private func skip() {
        supabase.needsTutorial = false
    }
}

#Preview {
    HowToUseView()
        .environmentObject(SupabaseService.shared)
}
