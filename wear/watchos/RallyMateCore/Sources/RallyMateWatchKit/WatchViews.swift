#if canImport(RallyMateCore)
import RallyMateCore
#endif
import Combine
import SwiftUI

public struct RallyMateWatchAppRoot: View {
    @StateObject private var viewModel: WatchMatchViewModel
    #if os(watchOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    @MainActor
    public init() {
        _viewModel = StateObject(wrappedValue: WatchMatchViewModel())
    }

    @MainActor
    public init(viewModel: WatchMatchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        root
    }

    @ViewBuilder
    private var root: some View {
        #if os(watchOS)
        WatchRootView(viewModel: viewModel)
            .task {
                viewModel.becameActive()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    viewModel.becameActive()
                case .inactive:
                    viewModel.prepareForInactive()
                case .background:
                    viewModel.prepareForBackground()
                @unknown default:
                    viewModel.prepareForBackground()
                }
            }
        #else
        WatchRootView(viewModel: viewModel)
        #endif
    }
}

private enum WatchSurface: Equatable {
    case main
    case newMatch
    /// Confirmation + health-recording choice before resuming a paused match.
    case resume(String)
    case menu
    case finish
    case abandon
    case assistant
    case voiceConfirmation
}

public struct WatchRootView: View {
    @ObservedObject private var viewModel: WatchMatchViewModel
    @State private var surface = WatchSurface.main
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    #else
    private let luminanceReduced = false
    #endif

    public init(viewModel: WatchMatchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            (viewModel.blindMode ? Color.black : WatchPalette.night)
                .ignoresSafeArea()

            content

            if !luminanceReduced,
               !viewModel.voiceFeedback.isEmpty,
               surface == .main,
               viewModel.pendingVoiceCommand == nil {
                VoiceFeedbackBanner(text: viewModel.voiceFeedback)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
        }
        .onReceive(viewModel.$finishConfirmationRequested.removeDuplicates()) { requested in
            if requested { surface = .finish }
        }
        .onReceive(viewModel.$pendingVoiceCommand) { command in
            if command != nil { surface = .voiceConfirmation }
        }
        .onReceive(viewModel.$state) { state in
            if state?.completed == true,
               surface != .finish,
               surface != .voiceConfirmation {
                surface = .main
            }
        }
        .animation(
            luminanceReduced ? nil : .easeOut(duration: 0.18),
            value: viewModel.scorePulse
        )
    }

    @ViewBuilder
    private var content: some View {
        switch surface {
        case .newMatch:
            WatchNewMatchView(viewModel: viewModel) {
                surface = .main
            } onStarted: {
                surface = .main
            }
        case let .resume(matchId):
            WatchResumeMatchView(viewModel: viewModel, matchId: matchId) {
                surface = .main
            } onResumed: {
                surface = .main
            }
        case .menu:
            MatchMenuView(viewModel: viewModel) { destination in
                surface = destination
            }
        case .finish:
            FinishMatchView(viewModel: viewModel) {
                viewModel.finishConfirmationRequested = false
                surface = .main
            } onConfirm: {
                viewModel.finishCurrentMatch()
                surface = .main
            }
        case .abandon:
            AbandonMatchView(viewModel: viewModel) {
                surface = .menu
            } onConfirm: {
                viewModel.abandonAsIncomplete()
                surface = .main
            }
        case .assistant:
            WatchAssistantQuickView(viewModel: viewModel) { surface = .main }
        case .voiceConfirmation:
            VoiceConfirmationView(viewModel: viewModel) {
                viewModel.cancelPendingVoiceCommand()
                surface = .main
            } onConfirm: {
                let finishing = viewModel.pendingVoiceCommand == .finish
                _ = viewModel.confirmPendingVoiceCommand()
                surface = finishing ? .finish : .main
            }
        case .main:
            mainContent
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let state = viewModel.state {
            if state.completed {
                MatchDoneView(viewModel: viewModel, state: state) {
                    viewModel.dismissCompletedMatch()
                    surface = .main
                } onNewMatch: {
                    viewModel.dismissCompletedMatch()
                    surface = .newMatch
                }
            } else if viewModel.blindMode {
                QuickScoringView(viewModel: viewModel, state: state) {
                    viewModel.blindMode = false
                } onMenu: {
                    surface = .menu
                } onFinish: {
                    surface = .finish
                }
            } else {
                ScoreView(viewModel: viewModel, state: state) {
                    surface = .menu
                }
            }
        } else {
            WatchHomeView(viewModel: viewModel) {
                surface = .newMatch
            } onResume: { matchId in
                surface = .resume(matchId)
            }
        }
    }
}

private struct WatchHomeView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let onNewMatch: () -> Void
    let onResume: (String) -> Void

    var body: some View {
        ZStack {
            WatchPalette.night
                .ignoresSafeArea()
            Image("RallyHomeCourt", bundle: rallyMateWatchResourceBundle)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .blendMode(.plusLighter)
                .opacity(0.28)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 9) {
                ZStack {
                    HStack {
                        if let profileImage = viewModel.profileImage {
                            Image(decorative: profileImage, scale: 1, orientation: .up)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                        } else {
                            Image("RallyAppMark", bundle: rallyMateWatchResourceBundle)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .accessibilityHidden(true)
                        }
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .center, spacing: 1) {
                        Text("Padelandia")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Label(
                            viewModel.syncStatus.connected ? "iPhone connesso" : "Pronto offline",
                            systemImage: viewModel.syncStatus.connected ? "iphone.radiowaves.left.and.right" : "checkmark.shield"
                        )
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            viewModel.syncStatus.connected
                                ? WatchPalette.lime
                                : .white.opacity(0.55)
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 34)

                if let message = viewModel.resumeBlockedMessage {
                    Button(action: viewModel.dismissResumeBlockedMessage) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(message)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WatchPalette.amber)
                    .background(WatchPalette.amber.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !viewModel.resumableMatches.isEmpty {
                    Text(
                        viewModel.resumableMatches.count == 1
                            ? "PARTITA DA RIPRENDERE"
                            : "PARTITE DA RIPRENDERE"
                    )
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Ordered by last activity so the most recent is on top.
                    ForEach(viewModel.resumableMatches) { match in
                        Button {
                            onResume(match.matchId)
                        } label: {
                            ResumableMatchRow(match: match)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            match.status == .paused
                                ? WatchPalette.amber
                                : WatchPalette.lime
                        )
                        .background(
                            (match.status == .paused
                                ? WatchPalette.amber
                                : WatchPalette.lime).opacity(0.13)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHint("Riapre la partita senza perdere i punti salvati")
                    }
                }

                Button {
                    _ = viewModel.createStandaloneMatch(
                        format: viewModel.lastFormat,
                        role: viewModel.selectedRole,
                        teamName: viewModel.accountContext.defaultTeamName
                    )
                } label: {
                    ZStack {
                        VStack(alignment: .center, spacing: 1) {
                            Text("Avvio rapido")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.74)
                            Text(viewModel.lastFormat.shortWatchName)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .opacity(0.67)
                        }
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)

                        HStack {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18, weight: .black))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.black)
                .background(WatchPalette.lime)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHint("Avvia con l'ultimo formato usato")

                Button(action: onNewMatch) {
                    ZStack {
                        Text("Nuova partita")
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 22)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Spacer(minLength: 0)
                        }
                    }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.white.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
        }
    }
}

/// One resumable match on the home screen: score, team, last activity.
private struct ResumableMatchRow: View {
    let match: WatchResumableMatch

    var body: some View {
        HStack(spacing: 8) {
            Image(
                systemName: match.status == .paused
                    ? "pause.circle.fill"
                    : "arrow.clockwise.circle.fill"
            )
            .font(.system(size: 19, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(match.teamLabel.isEmpty ? "Riprendi partita" : match.teamLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !match.scoreSummary.isEmpty {
                    Text(match.scoreSummary)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(match.subtitle)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .opacity(0.62)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .opacity(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .accessibilityElement(children: .combine)
    }
}

/// Resume confirmation. A resume opens a NEW health segment, so the recording
/// owner is asked again instead of being inherited from the first session.
private struct WatchResumeMatchView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let matchId: String
    let onCancel: () -> Void
    let onResumed: () -> Void

    @State private var recordingMode: WatchHealthRecordingMode

    init(
        viewModel: WatchMatchViewModel,
        matchId: String,
        onCancel: @escaping () -> Void,
        onResumed: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.matchId = matchId
        self.onCancel = onCancel
        self.onResumed = onResumed
        _recordingMode = State(initialValue: viewModel.lastHealthRecordingMode)
    }

    private var match: WatchResumableMatch? {
        viewModel.resumableMatches.first { $0.matchId == matchId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                WatchNavigationHeader(title: "Riprendi", onBack: onCancel)

                if let match {
                    VStack(alignment: .leading, spacing: 2) {
                        if !match.teamLabel.isEmpty {
                            Text(match.teamLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Text(match.scoreSummary)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                        Text(match.subtitle)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                        Text(match.format.shortWatchName)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }

                Text("REGISTRAZIONE DI QUESTA SESSIONE")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                ForEach(WatchHealthRecordingMode.allCases) { mode in
                    Button {
                        recordingMode = mode
                    } label: {
                        HStack(spacing: 6) {
                            Image(
                                systemName: recordingMode == mode
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                recordingMode == mode
                                    ? WatchPalette.lime
                                    : .white.opacity(0.3)
                            )
                            Text(mode.title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(recordingMode == mode ? 0.12 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                Text("La partita resta una sola; questa sessione crea un nuovo allenamento.")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    viewModel.resumeMatch(matchId, recordingMode: recordingMode)
                    onResumed()
                } label: {
                    WatchCenteredActionLabel(title: "Riprendi", systemName: "play.fill")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(WatchPalette.lime)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(WatchPalette.night)
    }
}

private struct WatchNewMatchView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let onCancel: () -> Void
    let onStarted: () -> Void

    @State private var formatId: String
    @State private var role: WatchPlayerRole
    @State private var teamName: String
    @State private var recordingMode: WatchHealthRecordingMode
    @State private var picker: MatchSetupPicker?

    init(
        viewModel: WatchMatchViewModel,
        onCancel: @escaping () -> Void,
        onStarted: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onCancel = onCancel
        self.onStarted = onStarted
        _formatId = State(initialValue: viewModel.lastFormat.id)
        _role = State(initialValue: viewModel.selectedRole)
        _recordingMode = State(initialValue: viewModel.lastHealthRecordingMode)
        _teamName = State(
            initialValue: viewModel.accountContext.defaultTeamName.isEmpty
                ? viewModel.accountContext.teamNames.first ?? ""
                : viewModel.accountContext.defaultTeamName
        )
    }

    var body: some View {
        if let picker {
            MatchSetupPickerView(
                picker: picker,
                formatId: $formatId,
                role: $role,
                teamName: $teamName,
                recordingMode: $recordingMode,
                teamNames: viewModel.accountContext.teamNames
            ) {
                self.picker = nil
            }
        } else {
            setupContent
        }
    }

    private var setupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                WatchNavigationHeader(title: "Nuova partita", onBack: onCancel)

                setupSection(title: "FORMATO", icon: "list.bullet.rectangle") {
                    setupSelectionButton(
                        title: selectedFormat.shortWatchName,
                        accessibilityLabel: "Formato della partita, \(selectedFormat.shortWatchName)"
                    ) {
                        picker = .format
                    }
                }

                setupSection(title: "RUOLO", icon: "figure.run") {
                    setupSelectionButton(
                        title: role.label,
                        accessibilityLabel: "Ruolo in campo, \(role.label)"
                    ) {
                        picker = .role
                    }
                }

                setupSection(
                    title: "REGISTRAZIONE ALLENAMENTO",
                    icon: recordingMode.symbolName
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        setupSelectionButton(
                            title: recordingMode.title,
                            accessibilityLabel: "Registrazione allenamento, \(recordingMode.title)"
                        ) {
                            picker = .recording
                        }
                        Text(WatchHealthRecordingMode.exclusivityNote)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !viewModel.accountContext.teamNames.isEmpty {
                    setupSection(title: "TEAM", icon: "person.2.fill") {
                        setupSelectionButton(
                            title: teamName.isEmpty ? "Nessun team" : teamName,
                            accessibilityLabel: "Team, \(teamName.isEmpty ? "nessun team" : teamName)"
                        ) {
                            picker = .team
                        }
                    }
                }

                HStack(spacing: 7) {
                    Image(systemName: viewModel.duoCreationAvailable ? "link.badge.plus" : "lock.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Duo Mode")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text(
                            viewModel.duoCreationAvailable
                                ? "Avvia da un invito Duo già autorizzato"
                                : "Richiede Plus e pairing sicuro su iPhone"
                        )
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    guard let selected = MatchFormat.presets.first(where: { $0.id == formatId })
                    else { return }
                    if viewModel.createStandaloneMatch(
                        format: selected,
                        role: role,
                        teamName: teamName,
                        recordingMode: recordingMode
                    ) {
                        onStarted()
                    }
                } label: {
                    WatchCenteredActionLabel(title: "Avvia partita", systemName: "play.fill")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(WatchPalette.lime)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(WatchPalette.night)
    }

    private var selectedFormat: MatchFormat {
        MatchFormat.presets.first(where: { $0.id == formatId }) ?? viewModel.lastFormat
    }

    private func setupSelectionButton(
        title: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(WatchPalette.lime)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .padding(.horizontal, 9)
        }
        .buttonStyle(.plain)
        .background(.black.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Apre tutte le opzioni")
    }

    private func setupSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
            content()
        }
        .padding(.horizontal, 22)
        .padding(.top, 7)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private enum MatchSetupPicker: Equatable {
    case format
    case role
    case team
    case recording

    var title: String {
        switch self {
        case .format: "Formato"
        case .role: "Ruolo"
        case .team: "Team"
        case .recording: "Registrazione"
        }
    }
}

private struct MatchSetupPickerView: View {
    let picker: MatchSetupPicker
    @Binding var formatId: String
    @Binding var role: WatchPlayerRole
    @Binding var teamName: String
    @Binding var recordingMode: WatchHealthRecordingMode
    let teamNames: [String]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            WatchNavigationHeader(title: picker.title, onBack: onClose)
                .padding(.horizontal, 10)
                .padding(.top, 12)

            #if os(watchOS)
            List {
                pickerRows
            }
            .listStyle(.carousel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            ScrollView {
                LazyVStack(spacing: 7) {
                    pickerRows
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchPalette.night)
        .accessibilityLabel("Selezione \(picker.title)")
    }

    @ViewBuilder
    private var pickerRows: some View {
        switch picker {
        case .format:
            ForEach(MatchFormat.presets, id: \.id) { format in
                optionRow(
                    title: format.shortWatchName,
                    selected: formatId == format.id
                ) {
                    formatId = format.id
                    onClose()
                }
            }
        case .role:
            ForEach(WatchPlayerRole.allCases) { value in
                optionRow(title: value.label, selected: role == value) {
                    role = value
                    onClose()
                }
            }
        case .team:
            ForEach(teamNames, id: \.self) { name in
                optionRow(title: name, selected: teamName == name) {
                    teamName = name
                    onClose()
                }
            }
        case .recording:
            ForEach(WatchHealthRecordingMode.allCases) { mode in
                optionRow(
                    title: mode.title,
                    subtitle: mode.subtitle,
                    selected: recordingMode == mode
                ) {
                    recordingMode = mode
                    onClose()
                }
            }
        }
    }

    private func optionRow(
        title: String,
        subtitle: String? = nil,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(.center)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 22)
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? WatchPalette.lime : .white.opacity(0.28))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(selected ? WatchPalette.lime.opacity(0.13) : .white.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? WatchPalette.lime.opacity(0.7) : .clear)
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
        .listRowBackground(Color.clear)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ScoreView: View {
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    #else
    private let luminanceReduced = false
    #endif

    @ObservedObject var viewModel: WatchMatchViewModel
    let state: MatchState
    let onMenu: () -> Void

    @ViewBuilder
    var body: some View {
        if luminanceReduced {
            AlwaysOnScoreView(
                score: scoreLine,
                state: state,
                pointSituation: pointSituation,
                synced: viewModel.synced
            )
        } else {
            interactiveScore
        }
    }

    private var interactiveScore: some View {
        VStack(spacing: 5) {
            MatchScoreHeader(
                score: scoreLine,
                state: state,
                pointSituation: pointSituation,
                pointSituationColor: pointSituationColor,
                metrics: viewModel.workoutMetrics,
                synced: viewModel.synced,
                connected: viewModel.syncStatus.connected
            ) {
                viewModel.synced ? viewModel.refreshFromPhone() : viewModel.retrySync()
            }

            if let notice = viewModel.workoutMetrics.notice {
                HealthNoticeBanner(
                    message: notice,
                    canRestart: viewModel.workoutMetrics.canRestartRecording,
                    onDismiss: viewModel.dismissHealthNotice,
                    onRestart: viewModel.restartHealthRecording
                )
            }

            if state.paused {
                Spacer(minLength: 2)
                VStack(spacing: 7) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(WatchPalette.amber)
                    Text("PARTITA IN PAUSA")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                    Button {
                        viewModel.resume()
                    } label: {
                        WatchCenteredActionLabel(title: "Riprendi", systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                    .background(WatchPalette.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Spacer(minLength: 2)
                MatchCommandBar(
                    viewModel: viewModel,
                    onQuickMode: {},
                    onMenu: onMenu,
                    quickModeEnabled: false
                )
            } else {
                HStack(spacing: 6) {
                    if let duoTeam = viewModel.duoTeam {
                        PointButton(
                            label: "NOI",
                            currentScore: score(for: duoTeam),
                            color: duoTeam == .a ? WatchPalette.lime : WatchPalette.blue,
                            image: scoringImage,
                            highlighted: viewModel.lastScoredTeam == duoTeam
                        ) {
                            viewModel.point(duoTeam)
                        }
                    } else {
                        PointButton(
                            label: "NOI",
                            currentScore: score(for: .a),
                            color: WatchPalette.lime,
                            image: scoringImage,
                            highlighted: viewModel.lastScoredTeam == .a
                        ) {
                            viewModel.point(.a)
                        }
                        PointButton(
                            label: "LORO",
                            currentScore: score(for: .b),
                            color: WatchPalette.blue,
                            highlighted: viewModel.lastScoredTeam == .b
                        ) {
                            viewModel.point(.b)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                MatchCommandBar(
                    viewModel: viewModel,
                    onQuickMode: { viewModel.blindMode = true },
                    onMenu: onMenu
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scoringImage: CGImage? {
        viewModel.teamScoringStyle == "COLOR" ? nil : viewModel.teamImage
    }

    private var scoreLine: String { scoreText(viewModel: viewModel, state: state) }

    private func score(for team: TeamId) -> String {
        teamScoreText(viewModel: viewModel, state: state, team: team)
    }

    private var pointSituation: String? {
        watchPointSituation(viewModel: viewModel, state: state)
    }

    private var pointSituationColor: Color {
        watchPointSituationColor(viewModel: viewModel, state: state)
    }
}

private struct MatchScoreHeader: View {
    let score: String
    let state: MatchState
    let pointSituation: String?
    let pointSituationColor: Color
    let metrics: WatchWorkoutMetrics
    let synced: Bool
    let connected: Bool
    let onSync: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 3) {
                VStack(alignment: .leading, spacing: 3) {
                    ServeIndicator(active: state.servingTeam == .a, color: WatchPalette.lime)
                    CompactWorkoutMetrics(metrics: metrics)
                }
                .frame(width: 38, alignment: .leading)
                AdaptiveScoreText(score: score, preferredSize: 33)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .layoutPriority(10)
                VStack(alignment: .trailing, spacing: 3) {
                    ServeIndicator(active: state.servingTeam == .b, color: WatchPalette.blue)
                    Button(action: onSync) {
                        Image(systemName: synced ? "icloud.fill" : "icloud.and.arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(synced ? WatchPalette.lime : WatchPalette.amber)
                            .frame(width: 25, height: 18)
                            .background(.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        synced
                            ? "Sincronizzato. Tocca per controllare lo stato"
                            : "Eventi in coda. Tocca per riprovare"
                    )
                }
                .frame(width: 38, alignment: .trailing)
            }

            HStack(spacing: 5) {
                ScoreStat(label: "SET", value: "\(state.setsA)-\(state.setsB)")
                ScoreStat(label: "GAME", value: "\(state.gamesA)-\(state.gamesB)")
                if state.inSuperTieBreak {
                    ScoreStat(label: "FASE", value: "STB")
                } else if state.inTieBreak {
                    ScoreStat(label: "FASE", value: "TB")
                }
            }

            if let pointSituation {
                Text(pointSituation)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(pointSituationColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            } else if state.sideChangePending {
                Text("CAMBIO CAMPO")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(WatchPalette.lime)
            }

        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct ScoreStat: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct CompactWorkoutMetrics: View {
    let metrics: WatchWorkoutMetrics

    var body: some View {
        HStack(spacing: 2) {
            if metrics.active {
                if let startedAt = metrics.startedAt {
                    Image(systemName: "timer")
                        .foregroundStyle(.white.opacity(0.48))
                    Text(startedAt, style: .timer)
                        .monospacedDigit()
                }
                if let heartRate = metrics.heartRateBPM {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(WatchPalette.coral)
                    Text("\(Int(heartRate.rounded()))")
                        .monospacedDigit()
                }
            } else {
                // Owner of the recording, so the user always knows whether an
                // allenamento is running and who owns it.
                Image(systemName: metrics.mode.symbolName)
                    .foregroundStyle(
                        metrics.state == .externalOwned || metrics.state == .failed
                            ? WatchPalette.amber
                            : .white.opacity(0.48)
                    )
            }
        }
        .font(.system(size: 7, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.62))
        .lineLimit(1)
        .minimumScaleFactor(0.68)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metrics.status)
    }
}

/// Explains an expected recording interruption without touching the match.
private struct HealthNoticeBanner: View {
    let message: String
    let canRestart: Bool
    let onDismiss: () -> Void
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WatchPalette.amber)
                Text(message)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 6) {
                Button("Ho capito", action: onDismiss)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.72))
                if canRestart {
                    Button("Riavvia", action: onRestart)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .buttonStyle(.plain)
                        .foregroundStyle(WatchPalette.lime)
                        .accessibilityHint(
                            "Apre una nuova registrazione: i dati resteranno divisi in segmenti"
                        )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchPalette.amber.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct MatchCommandBar: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let onQuickMode: () -> Void
    let onMenu: () -> Void
    var quickModeEnabled = true

    var body: some View {
        HStack(spacing: 7) {
            WatchIconButton(
                systemName: "arrow.uturn.backward",
                label: "Annulla ultimo punto",
                enabled: viewModel.canUndo && viewModel.state?.paused == false,
                action: viewModel.undo
            )
            VoiceAction(viewModel: viewModel)
            WatchIconButton(
                systemName: "rectangle.split.2x1.fill",
                label: "Modalita rapida Noi e Loro",
                enabled: quickModeEnabled,
                action: onQuickMode
            )
            WatchIconButton(
                systemName: "ellipsis",
                label: "Comandi partita",
                action: onMenu
            )
        }
        .frame(height: 36)
    }
}

private struct VoiceAction: View {
    @ObservedObject var viewModel: WatchMatchViewModel

    var body: some View {
        #if os(watchOS)
        TextFieldLink(
            prompt: Text("Dì: Noi, Loro, Annulla, Pausa o Termina partita"),
            label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
            },
            onSubmit: { text in
                viewModel.handleVoiceCommand(text)
            }
        )
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(.white.opacity(0.12))
        .clipShape(Circle())
        .accessibilityLabel("Comando vocale")
        .accessibilityHint("Ascolta solo dopo il tocco")
        #else
        WatchIconButton(
            systemName: "mic.slash",
            label: "Dettatura non disponibile",
            enabled: false,
            action: {}
        )
        #endif
    }
}

private struct QuickScoringView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let state: MatchState
    let onBack: () -> Void
    let onMenu: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                WatchIconButton(
                    systemName: "chevron.left",
                    label: "Torna allo scoring completo",
                    action: onBack
                )
                AdaptiveScoreText(
                    score: scoreText(viewModel: viewModel, state: state),
                    preferredSize: 25
                )
                    .frame(maxWidth: .infinity)
                    .layoutPriority(10)
                WatchIconButton(
                    systemName: "ellipsis",
                    label: "Altri comandi",
                    action: onMenu
                )
            }

            Text("Set \(state.setsA)-\(state.setsB)   Game \(state.gamesA)-\(state.gamesB)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()

            if state.paused {
                Spacer()
                Button {
                    viewModel.resume()
                } label: {
                    WatchCenteredActionLabel(title: "Riprendi partita", systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(WatchPalette.lime)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
            } else if let duoTeam = viewModel.duoTeam {
                QuickPointArea(
                    label: "NOI",
                    currentScore: teamScoreText(viewModel: viewModel, state: state, team: duoTeam),
                    color: WatchPalette.lime,
                    highlighted: viewModel.lastScoredTeam == duoTeam
                ) {
                    viewModel.point(duoTeam, blind: true)
                }
            } else {
                HStack(spacing: 5) {
                    QuickPointArea(
                        label: "NOI",
                        currentScore: teamScoreText(viewModel: viewModel, state: state, team: .a),
                        color: WatchPalette.lime,
                        highlighted: viewModel.lastScoredTeam == .a
                    ) {
                        viewModel.point(.a, blind: true)
                    }
                    QuickPointArea(
                        label: "LORO",
                        currentScore: teamScoreText(viewModel: viewModel, state: state, team: .b),
                        color: WatchPalette.blue,
                        highlighted: viewModel.lastScoredTeam == .b
                    ) {
                        viewModel.point(.b, blind: true)
                    }
                }
            }

            HStack(spacing: 8) {
                WatchIconButton(
                    systemName: "arrow.uturn.backward",
                    label: "Annulla ultimo punto",
                    enabled: viewModel.canUndo && !state.paused,
                    action: viewModel.undo
                )
                WatchIconButton(
                    systemName: state.paused ? "play.fill" : "pause.fill",
                    label: state.paused ? "Riprendi partita" : "Metti in pausa",
                    action: state.paused ? viewModel.resume : viewModel.pause
                )
                WatchIconButton(
                    systemName: "flag.checkered",
                    label: "Termina partita",
                    color: WatchPalette.coral,
                    action: onFinish
                )
            }
            .frame(height: 36)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

private struct QuickPointArea: View {
    let label: String
    let currentScore: String
    let color: Color
    let highlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(color.opacity(highlighted ? 0.46 : 0.22))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(highlighted ? 1 : 0.68), lineWidth: highlighted ? 3 : 1.5)
        )
        .scaleEffect(highlighted ? 0.975 : 1)
        .accessibilityLabel("Punto \(label). Punteggio attuale \(currentScore)")
    }
}

private struct MatchMenuView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let navigate: (WatchSurface) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 7) {
                WatchNavigationHeader(title: "Comandi") {
                    navigate(.main)
                }

                if let state = viewModel.state {
                    Text(
                        "\(scoreText(viewModel: viewModel, state: state))  ·  Set \(state.setsA)-\(state.setsB)  ·  Game \(state.gamesA)-\(state.gamesB)"
                    )
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                }

                WatchMenuButton(
                    title: viewModel.state?.paused == true ? "Riprendi" : "Pausa",
                    subtitle: viewModel.state?.paused == true
                        ? "Riattiva scoring e workout"
                        : "Conserva lo stato corrente",
                    systemName: viewModel.state?.paused == true ? "play.fill" : "pause.fill",
                    color: WatchPalette.amber
                ) {
                    if viewModel.state?.paused == true {
                        viewModel.resume()
                    } else {
                        viewModel.pause()
                    }
                    navigate(.main)
                }

                WatchMenuButton(
                    title: "Termina partita",
                    subtitle: "Salva risultato e statistiche",
                    systemName: "flag.checkered",
                    color: WatchPalette.coral
                ) {
                    navigate(.finish)
                }

                WatchMenuButton(
                    title: viewModel.synced ? "Controlla sync" : "Sincronizza ora",
                    subtitle: viewModel.synced ? "Confronta con iPhone" : "Eventi al sicuro sul Watch",
                    systemName: viewModel.synced ? "icloud.fill" : "icloud.and.arrow.up",
                    color: viewModel.synced ? WatchPalette.lime : WatchPalette.amber
                ) {
                    viewModel.synced ? viewModel.refreshFromPhone() : viewModel.retrySync()
                    navigate(.main)
                }

                WatchMenuButton(
                    title: "Regole rapide",
                    subtitle: "FAQ essenziali sul polso",
                    systemName: "questionmark.bubble.fill",
                    color: WatchPalette.blue
                ) {
                    navigate(.assistant)
                }

                WatchMenuButton(
                    title: "Salva come incompleta",
                    subtitle: "Potrai riprenderla dal Watch",
                    systemName: "archivebox.fill",
                    color: .white.opacity(0.72)
                ) {
                    navigate(.abandon)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(WatchPalette.night)
    }
}

private struct FinishMatchView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                WatchMascotImage(name: "rally_mascot_alert", size: 28)
                Text("Fine partita?")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            if let state = viewModel.state {
                Text(scoreText(viewModel: viewModel, state: state))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("Set \(state.setsA)-\(state.setsB)  ·  Game \(state.gamesA)-\(state.gamesB)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .monospacedDigit()
                Text("Salvata subito. Sync automatica.")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Button(action: onConfirm) {
                WatchCenteredActionLabel(title: "Termina e salva", systemName: "flag.checkered")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(WatchPalette.coral.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            Button("Continua a giocare", action: onCancel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .buttonStyle(.plain)
                .foregroundStyle(WatchPalette.lime)
                .padding(.vertical, 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(WatchPalette.night)
    }
}

private struct AbandonMatchView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(WatchPalette.amber)
            Text("Salvare come incompleta?")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Punti ed eventi restano sul Watch. Potrai riprendere o sincronizzare la partita in seguito.")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onConfirm) {
                Text("Salva e torna alla Home")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(WatchPalette.amber)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            Button("Annulla", action: onCancel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(13)
        .background(WatchPalette.night)
    }
}

private struct VoiceConfirmationView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 31, weight: .bold))
                .foregroundStyle(WatchPalette.blue)
            Text("Ho capito")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(viewModel.pendingVoiceCommand?.label ?? "Comando")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            if !viewModel.lastVoiceTranscript.isEmpty {
                Text("\"\(viewModel.lastVoiceTranscript)\"")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            HStack(spacing: 7) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button(action: onConfirm) {
                    Image(systemName: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(WatchPalette.lime)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(13)
        .background(WatchPalette.night)
    }
}

private struct MatchDoneView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let state: MatchState
    let onClose: () -> Void
    let onNewMatch: () -> Void

    private var won: Bool {
        guard let winner = state.winner else { return false }
        return winner == (viewModel.duoTeam ?? .a)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                WatchMascotImage(
                    name: won ? "rally_mascot_victory" : "rally_mascot_sync",
                    size: 30
                )
                Text(won ? "VITTORIA" : "PARTITA SALVATA")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(won ? WatchPalette.lime : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
            }

            if state.completedSets.isEmpty {
                HStack(spacing: 6) {
                    ScoreStat(label: "SET", value: "\(state.setsA)-\(state.setsB)")
                    ScoreStat(label: "GAME", value: "\(state.gamesA)-\(state.gamesB)")
                }
                Text(scoreText(viewModel: viewModel, state: state))
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Text(resultSummary(viewModel: viewModel, state: state))
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
            }

            Label(
                viewModel.synced ? "Sincronizzato" : "Sync in attesa",
                systemImage: viewModel.synced ? "icloud.fill" : "icloud.and.arrow.up"
            )
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(viewModel.synced ? WatchPalette.lime : WatchPalette.amber)

            if let quality = viewModel.healthQuality {
                HealthQualityRow(quality: quality)
            }

            // Correzione post-partita: se l'ultimo punto ha chiuso il match per
            // errore (game/set finale assegnato al team sbagliato), l'annulla
            // riapre la partita replayando gli eventi (undo event-sourced).
            if viewModel.canUndo {
                Button(action: viewModel.undo) {
                    WatchCenteredActionLabel(
                        title: "Annulla ultimo punto",
                        systemName: "arrow.uturn.backward"
                    )
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(WatchPalette.amber)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHint("Riapre la partita se il punteggio finale e errato")
            }

            HStack(spacing: 6) {
                Button(action: onClose) {
                    WatchCenteredActionLabel(title: "Home", systemName: "house.fill")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Button(action: onNewMatch) {
                    WatchCenteredActionLabel(title: "Nuova", systemName: "plus")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .background(WatchPalette.lime)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WatchPalette.night)
    }
}

/// States plainly what the saved health data covers, so a 5-minute segment is
/// never presented as a 90-minute match.
private struct HealthQualityRow: View {
    let quality: WatchHealthDataQuality

    private var color: Color {
        switch quality.completeness {
        case .complete: WatchPalette.lime
        case .partial: WatchPalette.amber
        case .external, .pending: WatchPalette.blue
        case .none: .white.opacity(0.5)
        }
    }

    private var symbol: String {
        switch quality.completeness {
        case .complete: "heart.text.square.fill"
        case .partial: "exclamationmark.triangle.fill"
        case .external: "figure.run.circle.fill"
        case .pending: "clock.fill"
        case .none: "heart.slash.fill"
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            Label(quality.label, systemImage: symbol)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(quality.detail)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AlwaysOnScoreView: View {
    let score: String
    let state: MatchState
    let pointSituation: String?
    let synced: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("RALLYMATE")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(WatchPalette.lime.opacity(0.42))
            AdaptiveScoreText(score: score, preferredSize: 38)
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity)
            HStack(spacing: 7) {
                ScoreStat(label: "SET", value: "\(state.setsA)-\(state.setsB)")
                ScoreStat(label: "GAME", value: "\(state.gamesA)-\(state.gamesB)")
            }
            if let pointSituation {
                Text(pointSituation)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.43))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Label(
                state.paused ? "IN PAUSA" : "PARTITA ATTIVA",
                systemImage: synced ? "icloud.fill" : "icloud.and.arrow.up"
            )
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.38))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Punteggio \(score), set \(state.setsA) a \(state.setsB), game \(state.gamesA) a \(state.gamesB)"
        )
    }
}

/// Keeps both sides of the score visible on every supported watch size.
/// `minimumScaleFactor` can still truncate a `Text` after sibling views have
/// consumed its proposal. Explicit fitting candidates avoid that ambiguity.
private struct AdaptiveScoreText: View {
    let score: String
    let preferredSize: CGFloat

    private var compactScore: String {
        score.replacingOccurrences(of: " ", with: "")
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            scoreLabel(score, size: preferredSize)
            scoreLabel(score, size: preferredSize * 0.88)
            scoreLabel(score, size: preferredSize * 0.76)
            scoreLabel(compactScore, size: max(preferredSize * 0.68, 18))
            scoreLabel(compactScore, size: 16)
        }
        .accessibilityLabel("Punteggio \(score)")
    }

    private func scoreLabel(_ value: String, size: CGFloat) -> some View {
        Text(verbatim: value)
            .font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct WatchAssistantQuickView: View {
    @ObservedObject var viewModel: WatchMatchViewModel
    let onClose: () -> Void
    @State private var answer = ""
    @State private var error = ""
    @State private var sources: [String] = []
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                WatchNavigationHeader(title: "Regole rapide", onBack: onClose)
                Text("Consultazione locale, disponibile anche senza rete.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                if viewModel.accountContext.assistantEnabled {
                    #if os(watchOS)
                    TextFieldLink(
                        prompt: Text("Chiedi una regola o un consiglio sulla partita"),
                        label: {
                            Label(
                                loading ? "Pallino sta pensando" : "Chiedi a Pallino",
                                systemImage: loading ? "ellipsis.bubble.fill" : "sparkles"
                            )
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                        },
                        onSubmit: ask
                    )
                    .buttonStyle(.plain)
                    .disabled(loading)
                    .foregroundStyle(.black)
                    .background(WatchPalette.lime)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHint("Usa la dettatura solo dopo il tocco")
                    #endif
                    if loading {
                        ProgressView()
                            .tint(WatchPalette.lime)
                            .frame(maxWidth: .infinity)
                    }
                    if !answer.isEmpty {
                        WatchAssistantCard(title: "Pallino", text: answer)
                        if !sources.isEmpty {
                            Text("Fonti: \(sources.joined(separator: " · "))")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.48))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else if !error.isEmpty {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(WatchPalette.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Label("Pallino richiede il piano Pro", systemImage: "lock.fill")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchPalette.amber)
                }
                WatchAssistantCard(
                    title: "Vantaggi",
                    text: "Sul 40 pari: AD al punto successivo. Punto avversario: si torna 40 pari."
                )
                WatchAssistantCard(
                    title: "Golden point",
                    text: "Sul 40-40 si gioca un punto secco. Chi risponde sceglie lato."
                )
                WatchAssistantCard(
                    title: "Servizio let",
                    text: "Rete e campo corretto: ripeti. Se e fuori, e fallo."
                )
                WatchAssistantCard(
                    title: "Cambio campo",
                    text: "Cambia ai game dispari e nei tie-break secondo formato."
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .background(WatchPalette.night)
    }

    private func ask(_ question: String) {
        guard !loading else { return }
        loading = true
        answer = ""
        error = ""
        sources = []
        Task {
            let reply = await WatchAssistantClient().ask(
                question: question,
                matchId: viewModel.activeMatchId.isEmpty ? nil : viewModel.activeMatchId,
                matchContext: matchContext
            )
            await MainActor.run {
                loading = false
                switch reply {
                case let .success(value):
                    answer = value.answer
                    sources = value.sourceTitles
                case let .failure(failure):
                    error = failure.message
                }
            }
        }
    }

    private var matchContext: String? {
        guard let state = viewModel.state else { return nil }
        return "Punteggio \(scoreText(viewModel: viewModel, state: state)); "
            + "set \(state.setsA)-\(state.setsB); game \(state.gamesA)-\(state.gamesB); "
            + "formato \(viewModel.activeFormat.id)."
    }
}

private struct WatchAssistantCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PointButton: View {
    let label: String
    let currentScore: String
    let color: Color
    var image: CGImage? = nil
    let highlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let image {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .resizable()
                        .scaledToFill()
                    LinearGradient(
                        colors: [.black.opacity(0.38), .black.opacity(0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [
                            color.opacity(highlighted ? 0.48 : 0.30),
                            color.opacity(highlighted ? 0.22 : 0.10),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                Text(label)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
                .foregroundStyle(image == nil ? color : .white)
                .shadow(color: .black.opacity(image == nil ? 0 : 0.7), radius: 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(highlighted ? 1 : 0.58), lineWidth: highlighted ? 3 : 1.5)
        )
        .scaleEffect(highlighted ? 0.975 : 1)
        .accessibilityLabel("Punto \(label). Punteggio attuale \(currentScore)")
    }
}

private struct WatchNavigationHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let ultraCompact = proxy.size.width < 150
            ZStack {
                Text(title)
                    .font(
                        .system(
                            size: ultraCompact ? 12 : 13,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .lineLimit(ultraCompact ? 2 : 1)
                    .minimumScaleFactor(0.68)
                    .multilineTextAlignment(.center)
                    .allowsTightening(true)
                    .padding(.horizontal, 36)
                    .frame(maxHeight: 34)
                HStack {
                    WatchIconButton(
                        systemName: "chevron.left",
                        label: "Indietro",
                        action: onBack
                    )
                    Spacer(minLength: 0)
                    Color.clear
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
    }
}

private struct WatchCenteredActionLabel: View {
    let title: String
    let systemName: String

    var body: some View {
        ZStack {
            Text(title)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            HStack {
                Image(systemName: systemName)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct WatchIconButton: View {
    let systemName: String
    let label: String
    var enabled = true
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .foregroundStyle(enabled ? color : .white.opacity(0.23))
        .background(.white.opacity(0.11))
        .clipShape(Circle())
        .contentShape(Circle())
        .accessibilityLabel(label)
    }
}

private struct WatchMenuButton: View {
    let title: String
    let subtitle: String
    let systemName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ServeIndicator: View {
    let active: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(active ? color : .clear)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(color.opacity(0.45), lineWidth: active ? 0 : 1))
            Text(active ? "SERV" : "")
                .font(.system(size: 5, weight: .black, design: .rounded))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 20)
        }
        .accessibilityLabel(active ? "Al servizio" : "")
    }
}

private struct VoiceFeedbackBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "waveform")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.black.opacity(0.88))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(WatchPalette.blue.opacity(0.45)))
    }
}

private struct WatchMascotImage: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(name, bundle: rallyMateWatchResourceBundle)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityHidden(true)
    }
}

@MainActor
private func scoreText(viewModel: WatchMatchViewModel, state: MatchState) -> String {
    if viewModel.isFreePlay {
        return "\(state.freePlayA) - \(state.freePlayB)"
    }
    if state.inTieBreak || state.inSuperTieBreak {
        return "\(state.tieBreakA) - \(state.tieBreakB)"
    }
    return "\(state.pointsLabel(.a)) - \(state.pointsLabel(.b))"
}

@MainActor
private func teamScoreText(
    viewModel: WatchMatchViewModel,
    state: MatchState,
    team: TeamId
) -> String {
    if viewModel.isFreePlay {
        return team == .a ? "\(state.freePlayA)" : "\(state.freePlayB)"
    }
    if state.inTieBreak || state.inSuperTieBreak {
        return team == .a ? "\(state.tieBreakA)" : "\(state.tieBreakB)"
    }
    return state.pointsLabel(team)
}

@MainActor
private func watchPointSituation(
    viewModel: WatchMatchViewModel,
    state: MatchState
) -> String? {
    guard !viewModel.isFreePlay else { return nil }
    return state.pointSituation(
        goldenPoint: viewModel.usesGoldenPoint,
        teamALabel: teamLabel(viewModel: viewModel, team: .a),
        teamBLabel: teamLabel(viewModel: viewModel, team: .b)
    )
}

@MainActor
private func watchPointSituationColor(
    viewModel: WatchMatchViewModel,
    state: MatchState
) -> Color {
    guard let advantage = state.advantage else { return WatchPalette.lime }
    if let duoTeam = viewModel.duoTeam {
        return advantage == duoTeam ? WatchPalette.lime : WatchPalette.blue
    }
    return advantage == .a ? WatchPalette.lime : WatchPalette.blue
}

@MainActor
private func teamLabel(viewModel: WatchMatchViewModel, team: TeamId) -> String {
    if let duoTeam = viewModel.duoTeam {
        return team == duoTeam ? "NOI" : "LORO"
    }
    return team == .a ? "NOI" : "LORO"
}

@MainActor
private func resultSummary(
    viewModel: WatchMatchViewModel,
    state: MatchState
) -> String {
    if !state.completedSets.isEmpty {
        return state.completedSets.map { set in
            if set.isSuperTieBreak {
                return "\(set.tieBreakA ?? 0)-\(set.tieBreakB ?? 0)"
            }
            return "\(set.gamesA)-\(set.gamesB)"
        }.joined(separator: "  ")
    }
    return "Set \(state.setsA)-\(state.setsB)\nGame \(state.gamesA)-\(state.gamesB) · \(scoreText(viewModel: viewModel, state: state))"
}

private extension MatchFormat {
    var shortWatchName: String {
        switch id {
        case "GOLDEN_BO3": "Golden point · 3 set"
        case "ADV_BO3": "Vantaggi · 3 set"
        case "SUPER_TB_BO3": "Super tie-break"
        case "SINGLE_SET": "Partita secca"
        case "TRAINING": "Allenamento libero"
        default: name
        }
    }
}

private var rallyMateWatchResourceBundle: Bundle {
    #if SWIFT_PACKAGE
    .module
    #else
    .main
    #endif
}

private enum WatchPalette {
    static let lime = Color(red: 0.78, green: 0.95, blue: 0.21)
    static let blue = Color(red: 0.35, green: 0.69, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.24)
    static let coral = Color(red: 1.0, green: 0.40, blue: 0.38)
    static let night = Color(red: 0.045, green: 0.065, blue: 0.11)
}
