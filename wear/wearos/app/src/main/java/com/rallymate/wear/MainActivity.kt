@file:OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)

package com.rallymate.wear

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.speech.RecognizerIntent
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.ambient.AmbientLifecycleObserver
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import java.util.Locale
import kotlinx.coroutines.launch

private val Lime = Color(0xFFC8F135)
private val Blue = Color(0xFF5AB0FF)
private val Night = Color(0xFF0C1220)
private val Amber = Color(0xFFFFB83D)
private val Coral = Color(0xFFFF665F)
private val StarGold = Color(0xFFFFD84D)

private enum class WearSurface { MAIN, SETUP, MENU, FINISH, ABANDON, ASSISTANT }

class MainActivity : ComponentActivity() {

    private val vm: MatchViewModel by viewModels()
    private var ambientMode by mutableStateOf(false)
    private var workoutDetectionLaunchAction by mutableStateOf<String?>(null)
    private val ambientCallback = object : AmbientLifecycleObserver.AmbientLifecycleCallback {
        override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) {
            ambientMode = true
        }

        override fun onExitAmbient() {
            ambientMode = false
        }

        override fun onUpdateAmbient() = Unit
    }
    private val ambientObserver by lazy { AmbientLifecycleObserver(this, ambientCallback) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycle.addObserver(ambientObserver)
        handleWorkoutDetectionIntent(intent)
        intent.getStringExtra("matchId")?.let { id ->
            val store = LocalMatchStore(this)
            val format = store.loadFormat(id) ?: MatchFormat()
            vm.startMatch(id, format, store.loadEvents(id))
        }
        setContent {
            MaterialTheme {
                WatchRoot(
                    vm = vm,
                    ambientMode = ambientMode,
                    workoutDetectionLaunchAction = workoutDetectionLaunchAction,
                    onWorkoutDetectionActionConsumed = {
                        workoutDetectionLaunchAction = null
                    },
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        vm.onAppForeground()
    }

    override fun onPause() {
        vm.onAppInactive()
        super.onPause()
    }

    override fun onStop() {
        vm.onAppBackground()
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWorkoutDetectionIntent(intent)
        intent.getStringExtra("matchId")?.let { id ->
            val store = LocalMatchStore(this)
            vm.startMatch(
                id,
                store.loadFormat(id) ?: MatchFormat(),
                store.loadEvents(id),
            )
        }
    }

    override fun onDestroy() {
        lifecycle.removeObserver(ambientObserver)
        super.onDestroy()
    }

    private fun handleWorkoutDetectionIntent(intent: Intent?) {
        workoutDetectionLaunchAction = when (intent?.action) {
            WorkoutDetectionIntents.ACTION_QUICK_START,
            WorkoutDetectionIntents.ACTION_CONFIGURE -> intent.action
            else -> null
        }
    }
}

@Composable
fun WatchRoot(
    vm: MatchViewModel,
    ambientMode: Boolean = false,
    workoutDetectionLaunchAction: String? = null,
    onWorkoutDetectionActionConsumed: () -> Unit = {},
) {
    val state = vm.state
    var surface by remember { mutableStateOf(WearSurface.MAIN) }
    var configureExternalWorkout by remember { mutableStateOf(false) }
    LaunchedEffect(workoutDetectionLaunchAction) {
        when (workoutDetectionLaunchAction) {
            WorkoutDetectionIntents.ACTION_QUICK_START -> {
                vm.createStandaloneMatch(
                    format = vm.lastFormat,
                    role = vm.selectedRole,
                    selectedTeamName = vm.accountContext.defaultTeamName,
                    externalWorkout = true,
                )
                surface = WearSurface.MAIN
            }
            WorkoutDetectionIntents.ACTION_CONFIGURE -> {
                configureExternalWorkout = true
                surface = WearSurface.SETUP
            }
        }
        if (workoutDetectionLaunchAction != null) {
            onWorkoutDetectionActionConsumed()
        }
    }
    LaunchedEffect(vm.finishConfirmationRequested) {
        if (vm.finishConfirmationRequested) surface = WearSurface.FINISH
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(if (vm.blindMode || ambientMode) Color.Black else Night)
    ) {
        when (surface) {
            WearSurface.SETUP -> NewMatchScreen(
                vm = vm,
                externalWorkout = configureExternalWorkout,
                onBack = {
                    configureExternalWorkout = false
                    surface = WearSurface.MAIN
                },
                onStarted = {
                    configureExternalWorkout = false
                    surface = WearSurface.MAIN
                },
            )
            WearSurface.MENU -> MatchMenuScreen(
                vm = vm,
                onBack = { surface = WearSurface.MAIN },
                onAssistant = { surface = WearSurface.ASSISTANT },
                onFinish = { surface = WearSurface.FINISH },
                onAbandon = { surface = WearSurface.ABANDON },
            )
            WearSurface.FINISH -> FinishConfirmScreen(
                vm = vm,
                onCancel = {
                    vm.finishConfirmationRequested = false
                    surface = WearSurface.MAIN
                },
                onConfirm = {
                    vm.finishCurrentMatch()
                    surface = WearSurface.MAIN
                },
            )
            WearSurface.ABANDON -> AbandonConfirmScreen(
                onCancel = { surface = WearSurface.MENU },
                onConfirm = {
                    vm.abandonAsIncomplete()
                    surface = WearSurface.MAIN
                },
            )
            WearSurface.ASSISTANT -> AssistantQuickScreen(
                vm = vm,
                onClose = { surface = WearSurface.MAIN },
            )
            WearSurface.MAIN -> when {
                state == null -> WearHomeScreen(
                    vm = vm,
                    onNewMatch = { surface = WearSurface.SETUP },
                    onDetectedWorkout = {
                        configureExternalWorkout = true
                        surface = WearSurface.SETUP
                    },
                )
                state.completed -> MatchDoneScreen(
                    vm = vm,
                    s = state,
                    onClose = {
                        vm.dismissCompletedMatch()
                        surface = WearSurface.MAIN
                    },
                    onNew = {
                        vm.dismissCompletedMatch()
                        surface = WearSurface.SETUP
                    },
                )
                vm.blindMode -> BlindScreen(
                    vm = vm,
                    s = state,
                    onBack = { vm.blindMode = false },
                    onMenu = { surface = WearSurface.MENU },
                    onFinish = { surface = WearSurface.FINISH },
                )
                else -> ScoreScreen(
                    vm,
                    state,
                    ambientMode = ambientMode,
                    onAssistant = { surface = WearSurface.ASSISTANT },
                    onMenu = { surface = WearSurface.MENU },
                )
            }
        }
        if (!vm.blindMode && surface == WearSurface.MAIN) TimeText()
    }
}

/** "Sospesa il 25 luglio alle 19:42" / "Attiva · 19:42". */
private fun resumeSubtitle(match: WearResumableMatch): String {
    val reference = match.pausedAtMs ?: match.updatedAtMs
    if (reference <= 0) return ""
    val now = java.util.Calendar.getInstance()
    val stamp = java.util.Calendar.getInstance().apply { timeInMillis = reference }
    val sameDay = now.get(java.util.Calendar.YEAR) == stamp.get(java.util.Calendar.YEAR) &&
        now.get(java.util.Calendar.DAY_OF_YEAR) == stamp.get(java.util.Calendar.DAY_OF_YEAR)
    val pattern = if (sameDay) "HH:mm" else "d MMMM 'alle' HH:mm"
    val text = java.text.SimpleDateFormat(pattern, java.util.Locale.ITALIAN)
        .format(java.util.Date(reference))
    return when {
        match.status == WearMatchStatus.PAUSED && sameDay -> "Sospesa alle $text"
        match.status == WearMatchStatus.PAUSED -> "Sospesa il $text"
        sameDay -> "Attiva · $text"
        else -> "Attiva dal $text"
    }
}

@Composable
fun WearHomeScreen(
    vm: MatchViewModel,
    onNewMatch: () -> Unit,
    onDetectedWorkout: () -> Unit = onNewMatch,
) {
    val context = LocalContext.current
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        WorkoutDetectionManager.ensureRegistration(context)
        vm.refreshWorkoutDetectionState()
    }
    val profileBitmap = remember(vm.profileImagePath) {
        vm.profileImagePath?.let(BitmapFactory::decodeFile)
    }
    Box(
        modifier = Modifier.fillMaxSize().background(Night),
    ) {
        Image(
            painter = painterResource(R.drawable.rally_home_court),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            alpha = 0.36f,
            modifier = Modifier.fillMaxSize(),
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 12.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(
                modifier = Modifier.fillMaxWidth().height(40.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (profileBitmap != null) {
                    Image(
                        bitmap = profileBitmap.asImageBitmap(),
                        contentDescription = "Foto profilo",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .align(Alignment.CenterStart)
                            .size(36.dp)
                            .clip(CircleShape),
                    )
                } else {
                    Box(Modifier.align(Alignment.CenterStart)) {
                        Image(
                            painter = painterResource(R.drawable.rally_app_mark),
                            contentDescription = null,
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.size(36.dp),
                        )
                    }
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "Momentum",
                        color = Color.White,
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Black,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        "Pronto anche offline",
                        color = Color(0x99FFFFFF),
                        fontSize = 9.sp,
                        textAlign = TextAlign.Center,
                    )
                }
            }
            vm.resumeBlockedMessage?.let { message ->
                Text(
                    message,
                    color = Amber,
                    fontSize = 10.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(Amber.copy(alpha = 0.16f))
                        .combinedClickable(onClick = vm::dismissResumeBlockedMessage)
                        .padding(10.dp),
                )
            }
            if (vm.resumableMatches.isNotEmpty()) {
                Text(
                    if (vm.resumableMatches.size == 1) "PARTITA DA RIPRENDERE"
                    else "PARTITE DA RIPRENDERE",
                    color = Color(0x77FFFFFF),
                    fontSize = 8.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 6.dp),
                )
                // Ordered by last activity so the most recent is on top.
                vm.resumableMatches.forEach { match ->
                    WearActionCard(
                        title = match.teamLabel.ifBlank { "Riprendi partita" },
                        subtitle = listOf(match.scoreSummary, resumeSubtitle(match))
                            .filter { it.isNotBlank() }
                            .joinToString(" · "),
                        glyph = if (match.status == WearMatchStatus.PAUSED) "II" else "↻",
                        color = if (match.status == WearMatchStatus.PAUSED) Amber else Lime,
                        onTap = { vm.resumeMatch(match.matchId) },
                    )
                }
            }
            vm.pendingDetectedWorkout?.let { detected ->
                WearActionCard(
                    title = "${detected.displayName} rilevato",
                    subtitle = "Configura una partita",
                    glyph = "!",
                    color = Amber,
                    onTap = onDetectedWorkout,
                )
                Text(
                    "Ignora questa attività",
                    color = Color(0x99FFFFFF),
                    fontSize = 9.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .combinedClickable(onClick = vm::ignorePendingDetectedWorkout)
                        .padding(4.dp),
                )
            }
            if (vm.workoutDetectionRegistrationStatus == "PERMISSION_REQUIRED") {
                WearActionCard(
                    title = "Attiva rilevamento",
                    subtitle = "Movimento e notifiche",
                    glyph = "?",
                    color = Blue,
                ) {
                    permissionLauncher.launch(detectionRuntimePermissions())
                }
            }
            WearActionCard(
                title = "Avvio rapido",
                subtitle = vm.lastFormat.shortWearName(),
                glyph = "⚡",
                color = Lime,
                darkText = true,
            ) {
                vm.createStandaloneMatch(
                    format = vm.lastFormat,
                    role = vm.selectedRole,
                    selectedTeamName = vm.accountContext.defaultTeamName,
                )
            }
            WearActionCard(
                title = "Nuova partita",
                subtitle = "Scegli formato e ruolo",
                glyph = "＋",
                color = Color(0x22FFFFFF),
                onTap = onNewMatch,
            )
        }
    }
}

@Composable
fun NewMatchScreen(
    vm: MatchViewModel,
    externalWorkout: Boolean = false,
    onBack: () -> Unit,
    onStarted: () -> Unit,
) {
    val formats = MatchFormat.PRESETS
    val roles = listOf("RIGHT", "LEFT", "FLEX")
    var formatIndex by remember {
        mutableIntStateOf(formats.indexOfFirst { it.id == vm.lastFormat.id }.coerceAtLeast(0))
    }
    var roleIndex by remember {
        mutableIntStateOf(roles.indexOf(vm.selectedRole).coerceAtLeast(0))
    }
    var recordingMode by remember {
        mutableStateOf(
            if (externalWorkout) {
                WearHealthRecordingMode.EXTERNAL_MANAGED
            } else {
                vm.lastHealthRecordingMode
            }
        )
    }
    val selectedTeam = vm.accountContext.defaultTeamName.ifBlank {
        vm.accountContext.teamNames.firstOrNull().orEmpty()
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 22.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        WearHeader("Nuova partita", onBack)
        Text("FORMATO", color = Color(0x77FFFFFF), fontSize = 8.sp,
            fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 6.dp))
        formats.forEachIndexed { index, format ->
            SelectionOption(
                value = format.shortWearName(),
                selected = formatIndex == index,
            ) { formatIndex = index }
        }
        Text(
            formats[formatIndex].wearDescription(),
            color = if (formats[formatIndex].gameScoringMode == GameScoringMode.STAR_POINT) {
                StarGold
            } else {
                Color(0x88FFFFFF)
            },
            fontSize = 9.sp,
            modifier = Modifier
                .padding(horizontal = 6.dp)
                .semantics {
                    contentDescription = formats[formatIndex].wearDescription()
                },
        )
        Text("RUOLO", color = Color(0x77FFFFFF), fontSize = 8.sp,
            fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 6.dp))
        roles.forEachIndexed { index, role ->
            SelectionOption(
                value = when (role) {
                    "RIGHT" -> "Destra"
                    "LEFT" -> "Sinistra"
                    else -> "Flex"
                },
                selected = roleIndex == index,
            ) { roleIndex = index }
        }
        Text("REGISTRAZIONE ALLENAMENTO", color = Color(0x77FFFFFF), fontSize = 8.sp,
            fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 6.dp))
        WearHealthRecordingMode.entries.forEach { mode ->
            SelectionOption(
                value = mode.title,
                selected = recordingMode == mode,
            ) { recordingMode = mode }
        }
        Text(
            WearHealthRecordingMode.EXCLUSIVITY_NOTE,
            color = Color(0x88FFFFFF),
            fontSize = 9.sp,
            modifier = Modifier.padding(horizontal = 6.dp),
        )
        if (selectedTeam.isNotBlank()) {
            Text("TEAM", color = Color(0x77FFFFFF), fontSize = 8.sp,
                fontWeight = FontWeight.Bold, modifier = Modifier.padding(horizontal = 6.dp))
            SelectionOption(value = selectedTeam, selected = true, onTap = {})
        }
        Text(
            if (vm.accountContext.premiumEnabled) {
                "Duo Mode: entra da un invito autorizzato sul telefono."
            } else {
                "Duo Mode richiede Plus e pairing sicuro."
            },
            color = Color(0x88FFFFFF),
            fontSize = 9.sp,
            modifier = Modifier.padding(horizontal = 6.dp),
        )
        WearActionCard(
            title = "Avvia partita",
            subtitle = "Salvataggio locale immediato",
            glyph = "▶",
            color = Lime,
            darkText = true,
        ) {
            if (vm.createStandaloneMatch(
                    format = formats[formatIndex],
                    role = roles[roleIndex],
                    selectedTeamName = selectedTeam,
                    externalWorkout = externalWorkout,
                    recordingMode = recordingMode,
                )
            ) onStarted()
        }
    }
}

@Composable
private fun SelectionOption(value: String, selected: Boolean, onTap: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) Lime.copy(alpha = 0.13f) else Color(0x16FFFFFF))
            .border(
                1.dp,
                if (selected) Lime.copy(alpha = 0.68f) else Color.Transparent,
                RoundedCornerShape(12.dp),
            )
            .combinedClickable(onClick = onTap)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            value,
            color = Color.White,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 3,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
        )
        Text(
            if (selected) "✓" else "○",
            color = if (selected) Lime else Color(0x55FFFFFF),
            fontSize = 13.sp,
            fontWeight = FontWeight.Black,
            modifier = Modifier.align(Alignment.CenterEnd),
        )
    }
}

@Composable
fun MatchMenuScreen(
    vm: MatchViewModel,
    onBack: () -> Unit,
    onAssistant: () -> Unit,
    onFinish: () -> Unit,
    onAbandon: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 22.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        WearHeader("Comandi", onBack)
        WearActionCard(
            title = if (vm.state?.paused == true) "Riprendi" else "Pausa",
            subtitle = "Stato salvato nella timeline",
            glyph = if (vm.state?.paused == true) "▶" else "Ⅱ",
            color = Amber,
        ) {
            if (vm.state?.paused == true) vm.resume() else vm.pause()
            onBack()
        }
        WearActionCard(
            "Termina partita",
            "Salva risultato e statistiche",
            "⚑",
            Coral,
            onTap = onFinish,
        )
        WearActionCard(
            title = if (vm.synced) "Sincronizzato" else "Sincronizza ora",
            subtitle = if (vm.synced) "Eventi confermati" else "Eventi al sicuro sul watch",
            glyph = "☁",
            color = if (vm.synced) Lime else Amber,
        ) {
            vm.retrySync()
            onBack()
        }
        WearActionCard("Regole rapide", "FAQ offline", "?", Blue, onTap = onAssistant)
        WearActionCard(
            "Salva come incompleta",
            "Riprendi in seguito",
            "□",
            Color(0x99FFFFFF),
            onTap = onAbandon,
        )
    }
}

@Composable
fun FinishConfirmScreen(
    vm: MatchViewModel,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
) {
    val state = vm.state ?: return
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 12.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
    ) {
        Text("Terminare la partita?", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Black)
        Text(scoreLine(vm, state), color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Black)
        Text(
            "Set ${state.setsA}-${state.setsB} · Game ${state.gamesA}-${state.gamesB}",
            color = Color(0x99FFFFFF),
            fontSize = 10.sp,
        )
        Text("Salvataggio locale immediato; sync automatica.", color = Color(0x77FFFFFF), fontSize = 8.sp)
        WearActionCard("Termina e salva", "Conferma esplicita", "⚑", Coral, onTap = onConfirm)
        Text(
            "Continua a giocare",
            color = Lime,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.combinedClickable(onClick = onCancel).padding(6.dp),
        )
    }
}

@Composable
fun AbandonConfirmScreen(onCancel: () -> Unit, onConfirm: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 13.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
    ) {
        Text("Salvare come incompleta?", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Black)
        Text(
            "Punti ed eventi restano sul watch e saranno sincronizzati appena possibile.",
            color = Color(0x99FFFFFF),
            fontSize = 9.sp,
        )
        WearActionCard("Salva e chiudi", "Potrai riprenderla", "□", Amber, onTap = onConfirm)
        Text("Annulla", color = Color.White, fontSize = 11.sp,
            modifier = Modifier.combinedClickable(onClick = onCancel).padding(6.dp))
    }
}

@Composable
private fun WearHeader(title: String, onBack: () -> Unit) {
    Box(
        modifier = Modifier.fillMaxWidth().height(38.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            title,
            color = Color.White,
            fontSize = 15.sp,
            fontWeight = FontWeight.Black,
            maxLines = 1,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 42.dp),
        )
        Box(Modifier.align(Alignment.CenterStart)) {
            SmallAction("‹", onTap = onBack)
        }
    }
}

@Composable
private fun WearActionCard(
    title: String,
    subtitle: String,
    glyph: String,
    color: Color,
    darkText: Boolean = false,
    onTap: () -> Unit,
) {
    val foreground = if (darkText) Color.Black else Color.White
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(15.dp))
            .background(color.copy(alpha = if (darkText) 1f else 0.17f))
            .border(1.dp, color.copy(alpha = 0.5f), RoundedCornerShape(15.dp))
            .combinedClickable(onClick = onTap)
            .padding(10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                title,
                color = foreground,
                fontSize = 12.sp,
                fontWeight = FontWeight.Black,
                textAlign = TextAlign.Center,
            )
            Text(
                subtitle,
                color = foreground.copy(alpha = 0.62f),
                fontSize = 8.sp,
                textAlign = TextAlign.Center,
            )
        }
        Text(
            glyph,
            color = if (darkText) Color.Black else color,
            fontSize = 18.sp,
            modifier = Modifier.align(Alignment.CenterStart),
        )
        Text(
            "›",
            color = foreground.copy(alpha = 0.65f),
            fontSize = 17.sp,
            modifier = Modifier.align(Alignment.CenterEnd),
        )
    }
}

private fun MatchFormat.shortWearName(): String = when (id) {
    "GOLDEN_BO3" -> "Golden point · 3 set"
    "STAR_POINT_BO3" -> "Star Point FIP 2026 · 3 set"
    "ADV_BO3" -> "Vantaggi · 3 set"
    "SUPER_TB_BO3" -> "Super tie-break"
    "MATCH_TB7_BO3" -> "Tie-break decisivo a 7"
    "MINI_SET_BO3" -> "Mini-set a 4 game"
    "ADV_NO_TB_THIRD_BO3" -> "Terzo set senza TB"
    "SINGLE_SET" -> "Partita secca"
    "TRAINING" -> "Allenamento libero"
    else -> name
}

private fun MatchFormat.wearDescription(): String {
    val game = when (gameScoringMode) {
        GameScoringMode.GOLDEN_POINT ->
            "Sul 40 pari punto secco, niente vantaggi. La risposta sceglie il lato."
        GameScoringMode.ADVANTAGE ->
            "Vantaggi tradizionali: servono due punti di scarto."
        GameScoringMode.STAR_POINT ->
            "Due cicli di vantaggio; al terzo deuce è Star Point. La risposta sceglie il lato."
    }
    val sets = when {
        freePlay -> null
        gamesPerSet != 6 -> "Set a $gamesPerSet game, tie-break sul $gamesPerSet-$gamesPerSet."
        superTieBreakDecider ->
            "Ultimo set sostituito da un tie-break a $superTieBreakPoints punti."
        !tieBreakInDecidingSet ->
            "Set decisivo senza tie-break: si va a due game di scarto."
        else -> null
    }
    return if (sets == null) game else "$game $sets"
}

/** PRD D1 — schermata principale: punteggio + due pulsanti grandi. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ScoreScreen(
    vm: MatchViewModel,
    s: MatchState,
    ambientMode: Boolean = false,
    onAssistant: () -> Unit,
    onMenu: () -> Unit,
) {
    val context = LocalContext.current
    var pendingPoint by remember { mutableStateOf<TeamId?>(null) }
    var requestedWorkoutPermissions by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        pendingPoint?.let { team ->
            vm.point(team)
            pendingPoint = null
        }
    }
    fun recordPoint(team: TeamId) {
        val missingPermissions = missingWorkoutPermissions(context)
        if (missingPermissions.isEmpty() || requestedWorkoutPermissions) {
            vm.point(team)
        } else {
            requestedWorkoutPermissions = true
            pendingPoint = team
            permissionLauncher.launch(missingPermissions.toTypedArray())
        }
    }

    if (ambientMode) {
        WearAmbientScore(vm = vm, state = s)
        return
    }
    val scoringContext = pointSituationAccessibility(vm, s)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 8.dp, vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Header punteggio
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            ServeDot(active = s.servingTeam == TeamId.A, color = Lime)
            Text(
                text = scoreLine(vm, s),
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Black,
            )
            ServeDot(active = s.servingTeam == TeamId.B, color = Blue)
            Text(
                if (vm.synced) "☁" else "↥",
                color = if (vm.synced) Lime else Amber,
                fontSize = 10.sp,
                modifier = Modifier.semantics {
                    contentDescription = if (vm.synced) "Sincronizzato" else "Eventi in coda"
                },
            )
        }
        Text(
            text = "Set ${s.setsA}-${s.setsB} · Game ${s.gamesA}-${s.gamesB}" +
                if (s.inSuperTieBreak) " · STB" else if (s.inTieBreak) " · TB" else "",
            color = Color(0x99FFFFFF),
            fontSize = 11.sp,
        )
        pointSituation(vm, s)?.let { situation ->
            Text(
                text = situation,
                color = pointSituationColor(vm, s).copy(
                    alpha = 1f,
                ),
                fontSize = 9.sp,
                fontWeight = FontWeight.Black,
                maxLines = 1,
                modifier = Modifier.semantics {
                    contentDescription = scoringContext ?: situation
                },
            )
        }
        pointSituationHint(s)?.let { hint ->
            Text(
                text = hint,
                color = StarGold.copy(alpha = 0.88f),
                fontSize = 8.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                modifier = Modifier.semantics {
                    contentDescription = hint
                },
            )
        }
        if (s.sideChangePending) {
            Text("⇄ CAMBIO CAMPO", color = Lime, fontSize = 11.sp,
                fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(6.dp))

        if (s.paused) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Amber.copy(alpha = 0.18f))
                    .border(1.dp, Amber.copy(alpha = 0.55f), RoundedCornerShape(18.dp))
                    .combinedClickable(onClick = vm::resume),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Ⅱ", color = Amber, fontSize = 28.sp, fontWeight = FontWeight.Black)
                    Text("PARTITA IN PAUSA", color = Color.White, fontSize = 11.sp,
                        fontWeight = FontWeight.Black)
                    Text("Tocca per riprendere", color = Color(0x99FFFFFF), fontSize = 9.sp)
                }
            }
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SmallAction("▶", onTap = vm::resume)
                SmallAction("•••", onTap = onMenu)
            }
            return
        }

        // Duo Mode: un solo pulsante, il team assegnato a questo watch.
        // Classico: due pulsanti grandi.
        val duoTeam = vm.duoTeam
        val scoringImagePath = vm.teamImagePath.takeIf {
            vm.teamScoringStyle != "COLOR"
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (duoTeam != null) {
                BigButton(
                    label = "NOI",
                    currentScore = teamScore(vm, s, duoTeam),
                    color = if (duoTeam == TeamId.A) Lime else Blue,
                    ambientMode = false,
                    imagePath = scoringImagePath,
                    scoringContext = scoringContext,
                    modifier = Modifier.weight(1f),
                    onTap = { recordPoint(duoTeam) },
                )
            } else {
                BigButton(
                    label = "NOI",
                    currentScore = teamScore(vm, s, TeamId.A),
                    color = Lime,
                    ambientMode = false,
                    imagePath = scoringImagePath,
                    scoringContext = scoringContext,
                    modifier = Modifier.weight(1f),
                    onTap = { recordPoint(TeamId.A) },
                )
                BigButton(
                    label = "LORO",
                    currentScore = teamScore(vm, s, TeamId.B),
                    color = Blue,
                    ambientMode = false,
                    scoringContext = scoringContext,
                    modifier = Modifier.weight(1f),
                    onTap = { recordPoint(TeamId.B) },
                )
            }
        }
        if (duoTeam != null) {
            Text(
                "DUO · segni per il tuo team",
                color = Color(0x99FFFFFF),
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.height(6.dp))

        // Undo + blind mode
        Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            SmallAction("↩", enabled = vm.canUndo) { vm.undo() }
            VoiceAction(vm)
            SmallAction("◐") { vm.blindMode = true }
            SmallAction("•••") { onMenu() }
        }
    }
}

@Composable
private fun WearAmbientScore(vm: MatchViewModel, state: MatchState) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(horizontal = 18.dp, vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            scoreLine(vm, state),
            color = Color(0xB8FFFFFF),
            fontSize = 30.sp,
            fontWeight = FontWeight.Black,
            maxLines = 1,
        )
        Spacer(Modifier.height(7.dp))
        Text(
            "SET ${state.setsA}-${state.setsB}   GAME ${state.gamesA}-${state.gamesB}",
            color = Color(0x70FFFFFF),
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
        pointSituation(vm, state)?.let {
            Spacer(Modifier.height(5.dp))
            Text(
                it,
                color = if (state.starPointActive) {
                    StarGold.copy(alpha = 0.58f)
                } else {
                    Color(0x68FFFFFF)
                },
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                modifier = Modifier.semantics {
                    contentDescription = pointSituationAccessibility(vm, state) ?: it
                },
            )
        }
    }
}

private fun missingWorkoutPermissions(context: Context): List<String> =
    workoutRuntimePermissions().filter { permission ->
        ContextCompat.checkSelfPermission(context, permission) != PackageManager.PERMISSION_GRANTED
    }

private fun workoutRuntimePermissions(): List<String> = buildList {
    add(Manifest.permission.ACTIVITY_RECOGNITION)
    add(Manifest.permission.BODY_SENSORS)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        add(Manifest.permission.POST_NOTIFICATIONS)
    }
}

private fun detectionRuntimePermissions(): Array<String> = buildList {
    add(Manifest.permission.ACTIVITY_RECOGNITION)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        add(Manifest.permission.POST_NOTIFICATIONS)
    }
}.toTypedArray()

@Composable
fun VoiceAction(vm: MatchViewModel) {
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        if (result.resultCode != Activity.RESULT_OK) return@rememberLauncherForActivityResult
        val text = result.data
            ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            ?.firstOrNull()
            .orEmpty()
        if (!vm.handleVoiceCommand(text)) {
            Toast.makeText(context, "Comando non riconosciuto", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(context, "Riconosciuto: $text", Toast.LENGTH_SHORT).show()
        }
    }
    SmallAction("🎙") {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.ITALY.toLanguageTag())
            putExtra(
                RecognizerIntent.EXTRA_PROMPT,
                "Noi, Loro, Annulla, Pausa, Riprendi o Termina partita",
            )
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        if (intent.resolveActivity(context.packageManager) == null) {
            Toast.makeText(
                context,
                "Dettatura non disponibile",
                Toast.LENGTH_SHORT,
            ).show()
        } else {
            launcher.launch(intent)
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun AssistantQuickScreen(vm: MatchViewModel, onClose: () -> Unit) {
    val scroll = rememberScrollState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var answer by remember { mutableStateOf("") }
    var sources by remember { mutableStateOf(emptyList<String>()) }
    var error by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        val question = result.data
            ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            ?.firstOrNull()
            .orEmpty()
        if (result.resultCode != Activity.RESULT_OK || question.isBlank()) {
            return@rememberLauncherForActivityResult
        }
        loading = true
        answer = ""
        error = ""
        sources = emptyList()
        scope.launch {
            val state = vm.state
            val matchContext = state?.let {
                "Punteggio ${scoreLine(vm, it)}; set ${it.setsA}-${it.setsB}; " +
                    "game ${it.gamesA}-${it.gamesB}; formato ${vm.activeFormat.id}."
            }
            val reply = WearAssistantClient(
                WearAssistantCredentialStore(context),
            ).ask(
                question = question,
                matchId = vm.activeMatchId.takeIf(String::isNotBlank),
                matchContext = matchContext,
            )
            loading = false
            answer = reply.answer.orEmpty()
            sources = reply.sources
            error = reply.error.orEmpty()
        }
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(scroll)
            .padding(horizontal = 10.dp, vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Pallino", color = Lime, fontWeight = FontWeight.Black, fontSize = 15.sp)
            SmallAction("×") { onClose() }
        }
        Text(
            "FAQ offline e Pallino via Wi-Fi/LTE, senza bloccare lo scoring.",
            color = Color(0x99FFFFFF),
            fontSize = 10.sp,
        )
        if (vm.accountContext.assistantEnabled) {
            WearActionCard(
                title = if (loading) "Pallino sta pensando" else "Chiedi a Pallino",
                subtitle = "Detta una domanda breve",
                glyph = "✦",
                color = Lime,
                darkText = true,
            ) {
                if (loading) return@WearActionCard
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.ITALY.toLanguageTag())
                    putExtra(
                        RecognizerIntent.EXTRA_PROMPT,
                        "Chiedi una regola o un consiglio sulla partita",
                    )
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                }
                if (intent.resolveActivity(context.packageManager) == null) {
                    error = "Dettatura non disponibile."
                } else {
                    launcher.launch(intent)
                }
            }
            if (answer.isNotBlank()) {
                AssistantFaqCard(title = "Pallino", body = answer)
                if (sources.isNotEmpty()) {
                    Text(
                        "Fonti: ${sources.joinToString(" · ")}",
                        color = Color(0x77FFFFFF),
                        fontSize = 8.sp,
                    )
                }
            } else if (error.isNotBlank()) {
                Text(error, color = Amber, fontSize = 9.sp)
            }
        } else {
            Text("Pallino richiede il piano Pro.", color = Amber, fontSize = 9.sp)
        }
        AssistantFaqCard(
            title = "Vantaggi",
            body = "Sul 40 pari: AD al punto successivo. Punto avversario: si torna a 40 pari.",
        )
        AssistantFaqCard(
            title = "Star Point FIP",
            body = "Deuce 1 e AD 1, poi Deuce 2 e AD 2. Al Deuce 3 punto decisivo: " +
                "chi riceve sceglie il lato, senza scambiarsi. Regola 1 Opzione 2.",
        )
        AssistantFaqCard(
            title = "Golden point",
            body = "Sul 40-40 punto secco, niente vantaggi: chi riceve sceglie il lato, " +
                "senza scambiarsi. Regola 1 Opzione 3.",
        )
        AssistantFaqCard(
            title = "Servizio let",
            body = "Se tocca rete e cade nel campo corretto si ripete. Let sul primo " +
                "servizio: due servizi nuovi. Sul secondo: ripeti solo il secondo.",
        )
        AssistantFaqCard(
            title = "Cambio campo",
            body = "Ogni game dispari. A fine set solo se il totale game è dispari: " +
                "dopo un 6-4 si cambia dopo il primo game del set dopo. Tie-break: ogni 6 punti.",
        )
        AssistantFaqCard(
            title = "In torneo",
            body = "Nei circuiti FIP 2026 l'orologio in gara va autorizzato dal Supervisor " +
                "o Referee: averlo installato non basta.",
        )
        AssistantFaqCard(
            title = "Training rapido",
            body = "In dubbio: volée controllata, uscita parete, lob alto. Pochi errori, tanta qualità.",
        )
    }
}

@Composable
fun AssistantFaqCard(title: String, body: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0x22FFFFFF))
            .border(1.dp, Color(0x16FFFFFF), RoundedCornerShape(16.dp))
            .padding(10.dp),
    ) {
        Text(title, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(3.dp))
        Text(body, color = Color(0xCCFFFFFF), fontSize = 10.sp)
    }
}

private fun scoreLine(vm: MatchViewModel, s: MatchState): String = when {
    vm.isFreePlay -> "  ${s.freePlayA} - ${s.freePlayB}  "
    s.inTieBreak || s.inSuperTieBreak -> "  ${s.tieBreakA} - ${s.tieBreakB}  "
    else -> "  ${s.pointsLabel(TeamId.A)} - ${s.pointsLabel(TeamId.B)}  "
}

private fun pointSituation(vm: MatchViewModel, s: MatchState): String? {
    if (vm.isFreePlay) return null
    fun label(team: TeamId): String {
        val duoTeam = vm.duoTeam
        if (duoTeam != null) return if (team == duoTeam) "NOI" else "LORO"
        return if (team == TeamId.A) "NOI" else "LORO"
    }
    val situation = s.pointSituation(
        teamALabel = label(TeamId.A),
        teamBLabel = label(TeamId.B),
    )
    return if (s.starPointActive && situation != null) "★ $situation" else situation
}

private fun pointSituationHint(s: MatchState): String? = s.pointSituationHint()

private fun pointSituationAccessibility(vm: MatchViewModel, s: MatchState): String? {
    if (vm.isFreePlay) return null
    fun label(team: TeamId): String {
        val duoTeam = vm.duoTeam
        if (duoTeam != null) return if (team == duoTeam) "NOI" else "LORO"
        return if (team == TeamId.A) "NOI" else "LORO"
    }
    return s.pointSituationAccessibility(
        teamALabel = label(TeamId.A),
        teamBLabel = label(TeamId.B),
    )
}

private fun pointSituationColor(vm: MatchViewModel, s: MatchState): Color {
    if (s.starPointActive) return StarGold
    val holder = s.advantage ?: return Lime
    val ownTeam = vm.duoTeam ?: TeamId.A
    return if (holder == ownTeam) Lime else Blue
}

@Composable
fun ServeDot(active: Boolean, color: Color) {
    Box(
        modifier = Modifier
            .size(8.dp)
            .clip(CircleShape)
            .background(if (active) color else Color.Transparent)
    )
}

@Composable
fun BigButton(
    label: String,
    currentScore: String,
    color: Color,
    modifier: Modifier = Modifier,
    ambientMode: Boolean = false,
    imagePath: String? = null,
    scoringContext: String? = null,
    onTap: () -> Unit,
) {
    val image = remember(imagePath) { imagePath?.let(::decodeWatchImage) }
    Box(
        modifier = modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.verticalGradient(
                    if (ambientMode) {
                        listOf(Color.Transparent, Color.Transparent)
                    } else {
                        listOf(color.copy(alpha = 0.30f), color.copy(alpha = 0.10f))
                    }
                )
            )
            .border(
                width = if (ambientMode) 1.dp else 1.5.dp,
                color = color.copy(alpha = if (ambientMode) 0.30f else 0.55f),
                shape = RoundedCornerShape(20.dp),
            )
            .semantics {
                contentDescription = buildString {
                    append("Punto $label. Punteggio attuale $currentScore.")
                    scoringContext?.let { append(" $it") }
                }
            }
            .combinedClickable(enabled = !ambientMode, onClick = onTap),
        contentAlignment = Alignment.Center,
    ) {
        if (image != null) {
            Image(
                bitmap = image,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Black.copy(alpha = 0.34f), Color.Black.copy(alpha = 0.72f))
                        )
                    )
            )
        }
        val contentColor = if (image == null) color else Color.White
        Text(
            label,
            color = contentColor.copy(alpha = if (ambientMode) 0.42f else 1f),
            fontSize = 18.sp,
            fontWeight = FontWeight.Black,
        )
    }
}

private fun decodeWatchImage(path: String): ImageBitmap? = runCatching {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    var sampleSize = 1
    while (
        bounds.outWidth / sampleSize > WearEnergyPolicy.MAX_IMAGE_PIXELS * 2 ||
        bounds.outHeight / sampleSize > WearEnergyPolicy.MAX_IMAGE_PIXELS * 2
    ) {
        sampleSize *= 2
    }
    BitmapFactory.decodeFile(
        path,
        BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = android.graphics.Bitmap.Config.RGB_565
        },
    )?.asImageBitmap()
}.getOrNull()

@Composable
fun SmallAction(glyph: String, enabled: Boolean = true, onTap: () -> Unit) {
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(Color(0x22FFFFFF))
            .combinedClickable(enabled = enabled, onClick = onTap),
        contentAlignment = Alignment.Center,
    ) {
        Text(glyph, fontSize = 16.sp,
            color = if (enabled) Color.White else Color(0x44FFFFFF))
    }
}

/**
 * PRD D2 — Blind Mode: schermo diviso in due, luminosità minima,
 * tap sinistra/destra, double-tap = undo. Feature distintiva.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun BlindScreen(
    vm: MatchViewModel,
    s: MatchState,
    onBack: () -> Unit,
    onMenu: () -> Unit,
    onFinish: () -> Unit,
) {
    val scoringContext = pointSituationAccessibility(vm, s)
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 7.dp, vertical = 19.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SmallAction("‹", onTap = onBack)
            Text(
                scoreLine(vm, s),
                color = Color.White,
                fontSize = 25.sp,
                fontWeight = FontWeight.Black,
                modifier = Modifier.weight(1f),
            )
            SmallAction("•••", onTap = onMenu)
        }
        Text(
            "Set ${s.setsA}-${s.setsB}   Game ${s.gamesA}-${s.gamesB}",
            color = Color(0x99FFFFFF),
            fontSize = 9.sp,
        )
        pointSituation(vm, s)?.let { situation ->
            Text(
                situation,
                color = pointSituationColor(vm, s),
                fontSize = 9.sp,
                fontWeight = FontWeight.Black,
                maxLines = 1,
                modifier = Modifier.semantics {
                    contentDescription = scoringContext ?: situation
                },
            )
        }
        pointSituationHint(s)?.let { hint ->
            Text(
                hint,
                color = StarGold.copy(alpha = 0.88f),
                fontSize = 8.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
        }
        if (s.paused) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .clip(RoundedCornerShape(18.dp))
                    .background(Amber.copy(alpha = 0.18f))
                    .combinedClickable(onClick = vm::resume),
                contentAlignment = Alignment.Center,
            ) {
                Text("▶  RIPRENDI", color = Amber, fontSize = 14.sp, fontWeight = FontWeight.Black)
            }
        } else {
            val duoTeam = vm.duoTeam
            Row(
                modifier = Modifier.fillMaxWidth().weight(1f),
                horizontalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                if (duoTeam != null) {
                    QuickArea(
                        label = "NOI",
                        currentScore = teamScore(vm, s, duoTeam),
                        color = Lime,
                        scoringContext = scoringContext,
                        modifier = Modifier.weight(1f),
                    ) { vm.point(duoTeam, blind = true) }
                } else {
                    QuickArea(
                        label = "NOI",
                        currentScore = teamScore(vm, s, TeamId.A),
                        color = Lime,
                        scoringContext = scoringContext,
                        modifier = Modifier.weight(1f),
                    ) { vm.point(TeamId.A, blind = true) }
                    QuickArea(
                        label = "LORO",
                        currentScore = teamScore(vm, s, TeamId.B),
                        color = Blue,
                        scoringContext = scoringContext,
                        modifier = Modifier.weight(1f),
                    ) { vm.point(TeamId.B, blind = true) }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SmallAction("↩", enabled = vm.canUndo && !s.paused, onTap = vm::undo)
            SmallAction(if (s.paused) "▶" else "Ⅱ") {
                if (s.paused) vm.resume() else vm.pause()
            }
            SmallAction("⚑", onTap = onFinish)
        }
    }
}

@Composable
private fun QuickArea(
    label: String,
    currentScore: String,
    color: Color,
    scoringContext: String? = null,
    modifier: Modifier,
    onTap: () -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxHeight()
            .clip(RoundedCornerShape(18.dp))
            .background(color.copy(alpha = 0.23f))
            .border(2.dp, color.copy(alpha = 0.75f), RoundedCornerShape(18.dp))
            .combinedClickable(onClick = onTap)
            .semantics {
                contentDescription = buildString {
                    append("Punto $label. Punteggio attuale $currentScore.")
                    scoringContext?.let { append(" $it") }
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(label, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Black)
        }
    }
}

private fun teamScore(vm: MatchViewModel, s: MatchState, team: TeamId): String = when {
    vm.isFreePlay -> if (team == TeamId.A) s.freePlayA.toString() else s.freePlayB.toString()
    s.inTieBreak || s.inSuperTieBreak ->
        if (team == TeamId.A) s.tieBreakA.toString() else s.tieBreakB.toString()
    else -> s.pointsLabel(team)
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MatchDoneScreen(
    vm: MatchViewModel,
    s: MatchState,
    onClose: () -> Unit,
    onNew: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // Duo Mode: "noi" è il team assegnato a questo watch.
        val won = s.winner == (vm.duoTeam ?: TeamId.A)
        MascotImage(
            resId = if (won) R.drawable.rally_mascot_victory else R.drawable.rally_mascot_sync,
            size = 42,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            if (won) "VITTORIA" else "FINE PARTITA",
            color = if (won) Lime else Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.Black,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            s.completedSets.joinToString("  ") {
                if (it.isSuperTieBreak) "${it.tieBreakA}-${it.tieBreakB}"
                else "${it.gamesA}-${it.gamesB}"
            },
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            if (vm.synced) "Sincronizzato col telefono ✓"
            else "In attesa di sync…",
            color = Color(0x88FFFFFF),
            fontSize = 10.sp,
        )
        // Honest verdict: a short segment is never presented as the match.
        vm.healthQuality?.let { quality ->
            Spacer(Modifier.height(3.dp))
            Text(
                quality.label,
                color = if (quality.isPartial) Amber else Color(0xAAFFFFFF),
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
            )
            Text(
                quality.detail,
                color = Color(0x88FFFFFF),
                fontSize = 9.sp,
                textAlign = TextAlign.Center,
            )
        }
        Spacer(Modifier.height(10.dp))
        // Correzione post-partita: se l'ultimo punto ha chiuso il match per
        // errore (game/set finale al team sbagliato), l'annulla riapre la
        // partita replayando gli eventi (undo event-sourced, team-scoped in Duo).
        if (vm.canUndo) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(14.dp))
                    .background(Amber.copy(alpha = 0.22f))
                    .combinedClickable(onClick = { vm.undo() })
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                Text("↩ Annulla ultimo punto", color = Amber, fontSize = 12.sp,
                    fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(6.dp))
        }
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(14.dp))
                .background(Lime.copy(alpha = 0.2f))
                .combinedClickable(onClick = onNew)
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Text("Nuova partita", color = Lime, fontSize = 13.sp,
                fontWeight = FontWeight.Bold)
        }
        Text(
            "Chiudi",
            color = Color(0x99FFFFFF),
            fontSize = 10.sp,
            modifier = Modifier.combinedClickable(onClick = onClose).padding(6.dp),
        )
    }
}

@Composable
fun MascotImage(resId: Int, size: Int) {
    Image(
        painter = painterResource(resId),
        contentDescription = null,
        modifier = Modifier
            .size(size.dp)
            .clip(RoundedCornerShape((size * 0.22f).dp)),
    )
}
