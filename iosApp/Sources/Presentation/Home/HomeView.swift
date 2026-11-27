import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel

    init(coordinator: AppCoordinator) {
        _viewModel = State(initialValue: HomeViewModel(coordinator: coordinator))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HomeHeaderView(
                        userName: viewModel.user?.name ?? "Learner",
                        streakDays: viewModel.user?.streakDays ?? 0,
                        progressFraction: viewModel.overallProgressFraction,
                        activePhase: viewModel.phases.first { $0.id == viewModel.user?.currentPhaseId }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)

                    ForEach(viewModel.phases) { phase in
                        PhaseHeaderView(phase: phase) {
                            ForEach(viewModel.skills(for: phase)) { skill in
                                SkillRowView(
                                    skill: skill,
                                    state: viewModel.displayState(skill: skill, phase: phase)
                                ) {
                                    viewModel.openSkill(skill)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
