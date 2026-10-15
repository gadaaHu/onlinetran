package com.example.eduverse.ui.classroom

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.border
import androidx.compose.ui.graphics.Brush
import androidx.compose.animation.core.*
import com.example.eduverse.data.EduVerseApi
import com.example.eduverse.data.LiveStudentPresence
import kotlinx.coroutines.launch

enum class ClassroomTab {
    VIDEO, WHITEBOARD, CHAT, CONTROLS
}

typealias LiveStudentState = LiveStudentPresence

fun getStudentAvatarGradient(name: String): Pair<Color, Color> {
    val hash = Math.abs(name.hashCode())
    val palettes = listOf(
        Color(0xFF6366F1) to Color(0xFF8B5CF6), // Indigo / Violet
        Color(0xFFEC4899) to Color(0xFFF43F5E), // Pink / Rose
        Color(0xFF10B981) to Color(0xFF06B6D4), // Emerald / Cyan
        Color(0xFFF59E0B) to Color(0xFFD97706), // Amber / Orange
        Color(0xFF3B82F6) to Color(0xFF1D4ED8), // Blue / Cobalt
        Color(0xFF8B5CF6) to Color(0xFFC084FC)  // Purple / Lavender
    )
    return palettes[hash % palettes.size]
}

fun getStudentInitials(name: String): String {
    val parts = name.trim().split(" ").filter { it.isNotBlank() }
    return when {
        parts.size >= 2 -> "${parts[0].first()}${parts[1].first()}".uppercase()
        parts.isNotEmpty() && parts[0].length >= 2 -> parts[0].take(2).uppercase()
        parts.isNotEmpty() -> parts[0].take(1).uppercase()
        else -> "ST"
    }
}

data class DrawPath(
    val points: List<Offset>,
    val color: Color,
    val strokeWidth: Float
)

data class ChatMessage(
    val sender: String,
    val text: String,
    val time: String,
    val isInstructor: Boolean = false
)

@OptIn(ExperimentalMaterial3Api::class)
@SuppressLint("SetJavaScriptEnabled")
@Composable
fun AndroidLiveClassroomScreen(
    roomName: String,
    lessonTitle: String,
    onLeaveClass: () -> Unit,
    modifier: Modifier = Modifier
) {
    var selectedTab by remember { mutableStateOf(ClassroomTab.VIDEO) }
    var isHandRaised by remember { mutableStateOf(false) }
    var activeReaction by remember { mutableStateOf<String?>(null) }
    val user = EduVerseApi.currentSession
    val displayName = user?.fullName ?: "Student"
    val isInstructor = user?.roles?.any { it.equals("Instructor", ignoreCase = true) || it.equals("Admin", ignoreCase = true) } == true
    val scope = rememberCoroutineScope()
    var isRoomLocked by remember { mutableStateOf(false) }
    var controlFeedback by remember { mutableStateOf<String?>(null) }
    var faceCount by remember { mutableIntStateOf(0) }
    var cameraPermissionGranted by remember { mutableStateOf(false) }
    var isCameraFullscreen by remember { mutableStateOf(false) }

    // Request camera permission
    val permissionLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        contract = androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted -> cameraPermissionGranted = granted }

    val liveStudents = remember {
        mutableStateListOf<LiveStudentPresence>().apply {
            addAll(EduVerseApi.sampleLiveStudents)
        }
    }
    var isCheckingPresence by remember { mutableStateOf(false) }
    var selectedStudentForProfile by remember { mutableStateOf<LiveStudentPresence?>(null) }
    var presenceFilter by remember { mutableStateOf("ALL") } // "ALL", "ONLINE", "OFFLINE", "HANDS"

    fun refreshLivePresence() {
        scope.launch {
            isCheckingPresence = true
            val res = EduVerseApi.getLivePresence(roomName)
            isCheckingPresence = false
            res.onSuccess { list ->
                liveStudents.clear()
                liveStudents.addAll(list)
            }
        }
    }

    LaunchedEffect(Unit) {
        permissionLauncher.launch(android.Manifest.permission.CAMERA)
        refreshLivePresence()
    }

    // Periodic heartbeat to report face presence and poll room status
    LaunchedEffect(faceCount, isHandRaised) {
        while (true) {
            kotlinx.coroutines.delay(10_000)
            EduVerseApi.sendLiveHeartbeat(
                roomName = roomName,
                isFaceDetected = faceCount > 0,
                faceCount = faceCount,
                isMicMuted = false,
                isVideoOff = false,
                isHandRaised = isHandRaised
            )
        }
    }

    // Whiteboard state
    val paths = remember { mutableStateListOf<DrawPath>() }
    var currentPath by remember { mutableStateOf<List<Offset>>(emptyList()) }
    var currentColor by remember { mutableStateOf(Color(0xFF8B5CF6)) }
    var currentStrokeWidth by remember { mutableFloatStateOf(8f) }

    // Chat state
    val chatMessages = remember {
        mutableStateListOf(
            ChatMessage("System", "Welcome to $lessonTitle! Live room is open.", "10:14 AM"),
            ChatMessage("Instructor (David)", "Hello class! Today we are covering state management and gesture handling.", "10:15 AM", isInstructor = true)
        )
    }
    var chatInput by remember { mutableStateOf("") }

    // WebView state
    var isWebLoading by remember { mutableStateOf(true) }
    var webLoadError by remember { mutableStateOf<String?>(null) }

    val jitsiUrl = remember(roomName, displayName) {
        val encodedName = java.net.URLEncoder.encode(displayName, "UTF-8")
        "https://meet.jit.si/$roomName#config.startWithAudioMuted=false&config.startWithVideoMuted=false&config.prejoinPageEnabled=false&userInfo.displayName=$encodedName"
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Surface(
                            shape = CircleShape,
                            color = Color(0xFFEF4444),
                            modifier = Modifier.size(8.dp)
                        ) {}
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = lessonTitle,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                            Text(
                                text = "Live Room: $roomName",
                                fontSize = 11.sp,
                                color = Color.White.copy(alpha = 0.6f)
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onLeaveClass) {
                        Text("←", fontSize = 20.sp, color = Color.White)
                    }
                },
                actions = {
                    Button(
                        onClick = onLeaveClass,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFEF4444)),
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text("Leave", fontSize = 12.sp, color = Color.White, fontWeight = FontWeight.Bold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0F0F1D))
            )
        },
        containerColor = Color(0xFF0A0A14),
        modifier = modifier
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Modern Segmented Classroom Mode Switcher
            val tabs = remember {
                listOf(
                    ClassroomTab.VIDEO to "📹 Video",
                    ClassroomTab.WHITEBOARD to "🎨 Board",
                    ClassroomTab.CHAT to "💬 Chat",
                    ClassroomTab.CONTROLS to "👥 Students"
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF0F0F1D))
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                tabs.forEach { (tab, label) ->
                    val isSelected = selectedTab == tab
                    Surface(
                        color = if (isSelected) Color(0xFF8B5CF6) else Color.White.copy(alpha = 0.08f),
                        shape = RoundedCornerShape(20.dp),
                        modifier = Modifier
                            .weight(1f)
                            .clickable { selectedTab = tab }
                    ) {
                        Text(
                            text = label,
                            fontSize = 11.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.7f),
                            modifier = Modifier
                                .padding(vertical = 8.dp)
                                .wrapContentWidth(Alignment.CenterHorizontally)
                        )
                    }
                }
            }

            // Main Content Area
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                when (selectedTab) {
                    ClassroomTab.VIDEO -> {
                        if (isCameraFullscreen) {
                            // Fullscreen Camera View - gives complete prominence to face detection & front camera
                            Box(modifier = Modifier.fillMaxSize()) {
                                if (cameraPermissionGranted) {
                                    FaceDetectionCameraView(
                                        isInstructor = isInstructor,
                                        onFaceCountChanged = { faceCount = it },
                                        isFullscreen = true,
                                        onToggleFullscreen = { isCameraFullscreen = false },
                                        modifier = Modifier.fillMaxSize()
                                    )
                                }
                            }
                        } else {
                            Column(modifier = Modifier.fillMaxSize()) {
                                // ── Interactive Lecture Stage (replaces the blank black box)
                                Card(
                                    shape = RoundedCornerShape(16.dp),
                                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)),
                                    modifier = Modifier
                                        .weight(0.50f)
                                        .fillMaxWidth()
                                        .padding(10.dp)
                                ) {
                                    Column(
                                        modifier = Modifier
                                            .fillMaxSize()
                                            .padding(14.dp),
                                        verticalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                    Surface(
                                                        shape = CircleShape,
                                                        color = Color(0xFF10B981).copy(alpha = 0.2f),
                                                        modifier = Modifier.size(24.dp)
                                                    ) {
                                                        Box(contentAlignment = Alignment.Center) {
                                                            Text("📡", fontSize = 12.sp)
                                                        }
                                                    }
                                                    Text(
                                                        text = "Live Lecture Stage",
                                                        fontWeight = FontWeight.Bold,
                                                        fontSize = 15.sp,
                                                        color = MaterialTheme.colorScheme.onSurface
                                                    )
                                                }

                                                Surface(
                                                    color = Color(0xFF10B981).copy(alpha = 0.15f),
                                                    shape = RoundedCornerShape(8.dp),
                                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF10B981).copy(alpha = 0.3f))
                                                ) {
                                                    Text(
                                                        text = "● IN PROGRESS",
                                                        fontSize = 10.sp,
                                                        fontWeight = FontWeight.Bold,
                                                        color = Color(0xFF10B981),
                                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                                                    )
                                                }
                                            }

                                            Text(
                                                text = lessonTitle,
                                                fontWeight = FontWeight.SemiBold,
                                                fontSize = 14.sp,
                                                color = MaterialTheme.colorScheme.primary
                                            )
                                            Text(
                                                text = "Room: $roomName • Instructor Active",
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.55f)
                                            )

                                            // Lecture notes / agenda card
                                            Surface(
                                                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
                                                shape = RoundedCornerShape(10.dp),
                                                modifier = Modifier.fillMaxWidth()
                                            ) {
                                                Column(modifier = Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                                    Text("📋 Module Highlights:", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                                                    Text("• High-Availability Architecture & Edge Streaming", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                                                    Text("• WebRTC Video Delivery & Face Attendance", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                                                    Text("• Live Interactive Whiteboard & Reaction Sync", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                                                }
                                            }

                                            // Live Student Presence Strip
                                            val onlineCount = liveStudents.count { it.isOnline }
                                            val offlineCount = liveStudents.count { !it.isOnline }
                                            Surface(
                                                onClick = { selectedTab = ClassroomTab.CONTROLS },
                                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                                                shape = RoundedCornerShape(10.dp),
                                                border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)),
                                                modifier = Modifier.fillMaxWidth()
                                            ) {
                                                Row(
                                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                                    horizontalArrangement = Arrangement.SpaceBetween,
                                                    verticalAlignment = Alignment.CenterVertically
                                                ) {
                                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                                        Row(horizontalArrangement = Arrangement.spacedBy((-6).dp)) {
                                                            liveStudents.filter { it.isOnline }.take(3).forEach { st ->
                                                                val (g1, g2) = getStudentAvatarGradient(st.name)
                                                                Box(
                                                                    modifier = Modifier
                                                                        .size(20.dp)
                                                                        .clip(CircleShape)
                                                                        .background(Brush.linearGradient(listOf(g1, g2)))
                                                                        .border(1.dp, Color(0xFF0F0F1D), CircleShape),
                                                                    contentAlignment = Alignment.Center
                                                                ) {
                                                                    Text(getStudentInitials(st.name).take(1), fontSize = 8.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                                                }
                                                            }
                                                        }
                                                        Text(
                                                            text = "👥 $onlineCount Online • $offlineCount Offline",
                                                            fontSize = 11.sp,
                                                            fontWeight = FontWeight.Bold,
                                                            color = MaterialTheme.colorScheme.onSurface
                                                        )
                                                    }
                                                    Text(
                                                        text = "Live Check →",
                                                        fontSize = 11.sp,
                                                        color = MaterialTheme.colorScheme.primary,
                                                        fontWeight = FontWeight.Bold
                                                    )
                                                }
                                            }
                                        }

                                        // Action buttons
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                                        ) {
                                            Button(
                                                onClick = { isCameraFullscreen = true },
                                                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                                                shape = RoundedCornerShape(10.dp),
                                                modifier = Modifier.weight(1f),
                                                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp)
                                            ) {
                                                Text("⛶ Full Camera", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                            }
                                            OutlinedButton(
                                                onClick = { selectedTab = ClassroomTab.WHITEBOARD },
                                                shape = RoundedCornerShape(10.dp),
                                                modifier = Modifier.weight(1f),
                                                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp)
                                            ) {
                                                Text("🎨 Whiteboard", fontSize = 11.sp)
                                            }
                                            OutlinedButton(
                                                onClick = { selectedTab = ClassroomTab.CHAT },
                                                shape = RoundedCornerShape(10.dp),
                                                modifier = Modifier.weight(1f),
                                                contentPadding = PaddingValues(horizontal = 6.dp, vertical = 6.dp)
                                            ) {
                                                Text("💬 Chat", fontSize = 11.sp)
                                            }
                                        }
                                    }
                                }

                                // ── Face Detection Camera Panel (bottom 50%)
                                Column(
                                    modifier = Modifier
                                        .weight(0.50f)
                                        .fillMaxWidth()
                                        .background(Color(0xFF080814))
                                ) {
                                    // Panel header
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .background(Color(0xFF0F0F1D))
                                            .padding(horizontal = 12.dp, vertical = 6.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                                        ) {
                                            Text("🔍", fontSize = 14.sp)
                                            Text(
                                                text = "Face Attendance & Video",
                                                color = Color.White,
                                                fontSize = 13.sp,
                                                fontWeight = FontWeight.Bold
                                            )
                                        }
                                        Row(
                                            modifier = Modifier
                                                .background(
                                                    color = if (faceCount > 0) Color(0x3310B981) else Color(0x33EF4444),
                                                    shape = RoundedCornerShape(12.dp)
                                                )
                                                .padding(horizontal = 10.dp, vertical = 3.dp),
                                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            androidx.compose.foundation.Canvas(Modifier.size(7.dp)) {
                                                drawCircle(if (faceCount > 0) androidx.compose.ui.graphics.Color(0xFF10B981) else androidx.compose.ui.graphics.Color(0xFFEF4444))
                                            }
                                            Text(
                                                text = if (faceCount > 0) "$faceCount face verified" else "No face",
                                                color = if (faceCount > 0) Color(0xFF10B981) else Color(0xFFEF4444),
                                                fontSize = 11.sp,
                                                fontWeight = FontWeight.SemiBold
                                            )
                                        }
                                    }

                                    // Camera + ML Kit face detection overlay
                                    if (cameraPermissionGranted) {
                                        FaceDetectionCameraView(
                                            isInstructor = isInstructor,
                                            onFaceCountChanged = { faceCount = it },
                                            isFullscreen = false,
                                            onToggleFullscreen = { isCameraFullscreen = true },
                                            modifier = Modifier.fillMaxSize()
                                        )
                                    } else {
                                        Box(
                                            modifier = Modifier
                                                .fillMaxSize()
                                                .background(Color(0xFF0F0F1D)),
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Column(
                                                horizontalAlignment = Alignment.CenterHorizontally,
                                                verticalArrangement = Arrangement.spacedBy(10.dp)
                                            ) {
                                                Text("📷", fontSize = 36.sp)
                                                Text(
                                                    text = "Camera permission required\nfor face detection",
                                                    color = Color.White.copy(alpha = 0.6f),
                                                    fontSize = 13.sp,
                                                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                                                )
                                                Button(
                                                    onClick = { permissionLauncher.launch(android.Manifest.permission.CAMERA) },
                                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8B5CF6))
                                                ) {
                                                    Text("Grant Camera Permission", fontSize = 12.sp)
                                                }
                                            }
                                        }
                                    } // end else (no camera permission)
                                } // end face detection panel Column
                            } // end non-fullscreen Column
                        } // end VIDEO tab else block
                    } // end ClassroomTab.VIDEO

                    ClassroomTab.WHITEBOARD -> {
                        Column(modifier = Modifier.fillMaxSize()) {
                            // Whiteboard Drawing Area
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .fillMaxWidth()
                                    .background(Color(0xFF1E1E30))
                                    .pointerInput(currentColor, currentStrokeWidth) {
                                        detectDragGestures(
                                            onDragStart = { offset ->
                                                currentPath = listOf(offset)
                                            },
                                            onDrag = { change, _ ->
                                                change.consume()
                                                currentPath = currentPath + change.position
                                            },
                                            onDragEnd = {
                                                if (currentPath.isNotEmpty()) {
                                                    paths.add(DrawPath(currentPath, currentColor, currentStrokeWidth))
                                                    currentPath = emptyList()
                                                }
                                            }
                                        )
                                    }
                            ) {
                                Canvas(modifier = Modifier.fillMaxSize()) {
                                    for (path in paths) {
                                        for (i in 0 until path.points.size - 1) {
                                            drawLine(
                                                color = path.color,
                                                start = path.points[i],
                                                end = path.points[i + 1],
                                                strokeWidth = path.strokeWidth,
                                                cap = StrokeCap.Round
                                            )
                                        }
                                    }
                                    for (i in 0 until currentPath.size - 1) {
                                        drawLine(
                                            color = currentColor,
                                            start = currentPath[i],
                                            end = currentPath[i + 1],
                                            strokeWidth = currentStrokeWidth,
                                            cap = StrokeCap.Round
                                        )
                                    }
                                }

                                if (paths.isEmpty() && currentPath.isEmpty()) {
                                    Text(
                                        text = "✏️ Touch & drag anywhere to draw notes and diagrams",
                                        color = Color.White.copy(alpha = 0.35f),
                                        fontSize = 13.sp,
                                        modifier = Modifier
                                            .align(Alignment.Center)
                                            .padding(16.dp)
                                    )
                                }
                            }

                            // Whiteboard Controls Bar
                            Surface(
                                color = Color(0xFF151528),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 12.dp, vertical = 8.dp),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    // Color palette
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        val palette = listOf(
                                            Color(0xFF8B5CF6),
                                            Color(0xFF3B82F6),
                                            Color(0xFF10B981),
                                            Color(0xFFF59E0B),
                                            Color.White
                                        )
                                        palette.forEach { color ->
                                            Box(
                                                modifier = Modifier
                                                    .size(26.dp)
                                                    .background(color, CircleShape)
                                                    .clickable { currentColor = color }
                                            ) {
                                                if (currentColor == color) {
                                                    Surface(
                                                        shape = CircleShape,
                                                        color = Color.Transparent,
                                                        border = androidx.compose.foundation.BorderStroke(2.dp, Color.White),
                                                        modifier = Modifier.fillMaxSize()
                                                    ) {}
                                                }
                                            }
                                        }
                                    }

                                    // Actions: Undo & Clear
                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        TextButton(
                                            onClick = {
                                                if (paths.isNotEmpty()) paths.removeAt(paths.lastIndex)
                                            }
                                        ) {
                                            Text("↩ Undo", fontSize = 12.sp, color = Color.White.copy(alpha = 0.8f))
                                        }
                                        TextButton(
                                            onClick = { paths.clear() }
                                        ) {
                                            Text("🗑 Clear", fontSize = 12.sp, color = Color(0xFFEF4444))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ClassroomTab.CHAT -> {
                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(Color(0xFF0F0F1D))
                        ) {
                            LazyColumn(
                                modifier = Modifier
                                    .weight(1f)
                                    .fillMaxWidth()
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                items(chatMessages) { msg ->
                                    Column(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .background(
                                                color = if (msg.isInstructor) Color(0xFF8B5CF6).copy(alpha = 0.15f) else Color.White.copy(alpha = 0.05f),
                                                shape = RoundedCornerShape(10.dp)
                                            )
                                            .padding(10.dp)
                                    ) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Text(
                                                text = msg.sender,
                                                fontWeight = FontWeight.Bold,
                                                color = if (msg.isInstructor) Color(0xFFA78BFA) else Color.White,
                                                fontSize = 12.sp
                                            )
                                            Text(
                                                text = msg.time,
                                                color = Color.White.copy(alpha = 0.4f),
                                                fontSize = 10.sp
                                            )
                                        }
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text(
                                            text = msg.text,
                                            color = Color.White,
                                            fontSize = 13.sp
                                        )
                                    }
                                }
                            }

                            // Chat input bar
                            Surface(
                                color = Color(0xFF151528),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    OutlinedTextField(
                                        value = chatInput,
                                        onValueChange = { chatInput = it },
                                        placeholder = { Text("Ask a question...", color = Color.White.copy(alpha = 0.4f), fontSize = 13.sp) },
                                        singleLine = true,
                                        modifier = Modifier.weight(1f),
                                        shape = RoundedCornerShape(12.dp),
                                        colors = OutlinedTextFieldDefaults.colors(
                                            focusedTextColor = Color.White,
                                            unfocusedTextColor = Color.White,
                                            focusedBorderColor = Color(0xFF8B5CF6),
                                            unfocusedBorderColor = Color.White.copy(alpha = 0.2f)
                                        )
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Button(
                                        onClick = {
                                            if (chatInput.isNotBlank()) {
                                                chatMessages.add(
                                                    ChatMessage(
                                                        sender = displayName,
                                                        text = chatInput.trim(),
                                                        time = "10:16 AM"
                                                    )
                                                )
                                                chatInput = ""
                                            }
                                        },
                                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8B5CF6)),
                                        shape = RoundedCornerShape(12.dp),
                                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp)
                                    ) {
                                        Text("Send", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }

                    ClassroomTab.CONTROLS -> {
                        val onlineCount = liveStudents.count { it.isOnline }
                        val offlineCount = liveStudents.count { !it.isOnline }
                        val verifiedCount = liveStudents.count { it.isOnline && it.isFaceVerified }
                        val handsCount = liveStudents.count { it.isHandRaised }

                        val filteredStudents = remember(presenceFilter, liveStudents.toList()) {
                            when (presenceFilter) {
                                "ONLINE" -> liveStudents.filter { it.isOnline }
                                "OFFLINE" -> liveStudents.filter { !it.isOnline }
                                "HANDS" -> liveStudents.filter { it.isHandRaised }
                                else -> liveStudents
                            }
                        }

                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(Color(0xFF0A0A14))
                                .padding(14.dp)
                        ) {
                            // Header: Room & Live Presence Controls
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Text("👥", fontSize = 18.sp)
                                        Text(
                                            text = "Student Live Presence",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 17.sp,
                                            color = Color.White
                                        )
                                    }
                                    Text(
                                        text = "$onlineCount Online • $offlineCount Offline • Face Verification Active",
                                        fontSize = 11.sp,
                                        color = Color.White.copy(alpha = 0.6f)
                                    )
                                }

                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    // Live Check button
                                    FilledTonalButton(
                                        onClick = { refreshLivePresence() },
                                        enabled = !isCheckingPresence,
                                        colors = ButtonDefaults.filledTonalButtonColors(
                                            containerColor = Color(0xFF8B5CF6).copy(alpha = 0.25f)
                                        ),
                                        shape = RoundedCornerShape(10.dp),
                                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp)
                                    ) {
                                        Text(
                                            text = if (isCheckingPresence) "🔄 Checking..." else "⚡ Live Check",
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFFA78BFA)
                                        )
                                    }

                                    if (isInstructor) {
                                        FilledTonalButton(
                                            onClick = {
                                                isRoomLocked = !isRoomLocked
                                                controlFeedback = if (isRoomLocked) "🔒 Room locked for new students." else "🔓 Room unlocked."
                                            },
                                            colors = ButtonDefaults.filledTonalButtonColors(
                                                containerColor = if (isRoomLocked) Color(0xFFEF4444).copy(alpha = 0.2f) else Color.White.copy(alpha = 0.1f)
                                            ),
                                            shape = RoundedCornerShape(10.dp),
                                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp)
                                        ) {
                                            Text(
                                                text = if (isRoomLocked) "🔒 Locked" else "🔓 Open",
                                                fontSize = 11.sp,
                                                color = if (isRoomLocked) Color(0xFFF87171) else Color.White
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // ── Live Presence KPI Strip
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                // Online KPI
                                Surface(
                                    color = Color(0xFF10B981).copy(alpha = 0.15f),
                                    shape = RoundedCornerShape(12.dp),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF10B981).copy(alpha = 0.35f)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Column(
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            Box(modifier = Modifier.size(7.dp).clip(CircleShape).background(Color(0xFF10B981)))
                                            Text("$onlineCount", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color(0xFF34D399))
                                        }
                                        Text("Online", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f), maxLines = 1)
                                    }
                                }

                                // Offline KPI
                                Surface(
                                    color = Color.White.copy(alpha = 0.05f),
                                    shape = RoundedCornerShape(12.dp),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color.White.copy(alpha = 0.15f)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Column(
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            Box(modifier = Modifier.size(7.dp).clip(CircleShape).background(Color(0xFF94A3B8)))
                                            Text("$offlineCount", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color(0xFFCBD5E1))
                                        }
                                        Text("Offline", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f), maxLines = 1)
                                    }
                                }

                                // Face Verified KPI
                                Surface(
                                    color = Color(0xFF6366F1).copy(alpha = 0.15f),
                                    shape = RoundedCornerShape(12.dp),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF6366F1).copy(alpha = 0.35f)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Column(
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            Text("👤", fontSize = 11.sp)
                                            Text("$verifiedCount", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color(0xFFA5B4FC))
                                        }
                                        Text("Verified", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f), maxLines = 1)
                                    }
                                }

                                // Hand Raised KPI
                                Surface(
                                    color = Color(0xFFF59E0B).copy(alpha = 0.15f),
                                    shape = RoundedCornerShape(12.dp),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFF59E0B).copy(alpha = 0.35f)),
                                    modifier = Modifier.weight(1f)
                                ) {
                                    Column(
                                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            Text("✋", fontSize = 11.sp)
                                            Text("$handsCount", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color(0xFFFBBF24))
                                        }
                                        Text("Hands", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f), maxLines = 1)
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // ── Filter Pills Row (Horizontally Scrollable)
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                val filters = listOf(
                                    "ALL" to "All (${liveStudents.size})",
                                    "ONLINE" to "🟢 Online ($onlineCount)",
                                    "OFFLINE" to "⚪ Offline ($offlineCount)",
                                    "HANDS" to "✋ Hands ($handsCount)"
                                )
                                filters.forEach { (key, label) ->
                                    val isSelected = presenceFilter == key
                                    Surface(
                                        onClick = { presenceFilter = key },
                                        color = if (isSelected) Color(0xFF8B5CF6) else Color.White.copy(alpha = 0.08f),
                                        shape = RoundedCornerShape(20.dp),
                                        border = androidx.compose.foundation.BorderStroke(
                                            1.dp,
                                            if (isSelected) Color(0xFF8B5CF6) else Color.White.copy(alpha = 0.15f)
                                        )
                                    ) {
                                        Text(
                                            text = label,
                                            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.8f),
                                            fontSize = 12.sp,
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                            maxLines = 1,
                                            softWrap = false,
                                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp)
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            // Feedback banner
                            if (controlFeedback != null) {
                                Surface(
                                    color = Color(0xFF8B5CF6).copy(alpha = 0.2f),
                                    shape = RoundedCornerShape(8.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text(
                                        text = controlFeedback ?: "",
                                        color = Color(0xFFA78BFA),
                                        fontSize = 12.sp,
                                        modifier = Modifier.padding(8.dp)
                                    )
                                }
                                Spacer(modifier = Modifier.height(8.dp))
                            }

                            // ── Student List (Recognizable profiles)
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                verticalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                items(filteredStudents, key = { it.id }) { student ->
                                    val (gradStart, gradEnd) = getStudentAvatarGradient(student.name)
                                    val initials = getStudentInitials(student.name)

                                    Card(
                                        onClick = { selectedStudentForProfile = student },
                                        shape = RoundedCornerShape(14.dp),
                                        colors = CardDefaults.cardColors(containerColor = Color(0xFF141426)),
                                        border = androidx.compose.foundation.BorderStroke(
                                            1.dp,
                                            if (student.isOnline) Color(0xFF10B981).copy(alpha = 0.35f)
                                            else Color.White.copy(alpha = 0.08f)
                                        ),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Column(modifier = Modifier.padding(12.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                // Recognizable Student Avatar + Details
                                                Row(
                                                    verticalAlignment = Alignment.CenterVertically,
                                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                                    modifier = Modifier.weight(1f)
                                                ) {
                                                    // Distinct Colorful Avatar with Live Ring
                                                    Box(
                                                        modifier = Modifier
                                                            .size(46.dp)
                                                            .clip(CircleShape)
                                                            .background(Brush.linearGradient(listOf(gradStart, gradEnd)))
                                                            .border(
                                                                width = 2.dp,
                                                                color = if (student.isOnline) Color(0xFF10B981) else Color(0xFF64748B),
                                                                shape = CircleShape
                                                            ),
                                                        contentAlignment = Alignment.Center
                                                    ) {
                                                        Text(
                                                            text = initials,
                                                            fontWeight = FontWeight.ExtraBold,
                                                            color = Color.White,
                                                            fontSize = 16.sp
                                                        )
                                                        // Online Beacon Dot
                                                        Box(
                                                            modifier = Modifier
                                                                .size(11.dp)
                                                                .align(Alignment.BottomEnd)
                                                                .clip(CircleShape)
                                                                .background(if (student.isOnline) Color(0xFF10B981) else Color(0xFF94A3B8))
                                                                .border(1.5.dp, Color(0xFF141426), CircleShape)
                                                        )
                                                    }

                                                    // Student Identity Information
                                                    Column(modifier = Modifier.weight(1f)) {
                                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                            Text(
                                                                text = student.name,
                                                                fontWeight = FontWeight.Bold,
                                                                color = Color.White,
                                                                fontSize = 14.sp
                                                            )
                                                            if (student.isHandRaised) {
                                                                Surface(
                                                                    color = Color(0xFFF59E0B).copy(alpha = 0.2f),
                                                                    shape = RoundedCornerShape(6.dp),
                                                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFF59E0B).copy(alpha = 0.5f))
                                                                ) {
                                                                    Row(
                                                                        verticalAlignment = Alignment.CenterVertically,
                                                                        horizontalArrangement = Arrangement.spacedBy(3.dp),
                                                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                                                    ) {
                                                                        Text("✋", fontSize = 10.sp)
                                                                        Text("Hand Raised", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFFFBBF24))
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                            Surface(
                                                                color = Color(0xFF6366F1).copy(alpha = 0.2f),
                                                                shape = RoundedCornerShape(4.dp)
                                                            ) {
                                                                Text(
                                                                    text = student.studentId,
                                                                    color = Color(0xFFA5B4FC),
                                                                    fontSize = 9.sp,
                                                                    fontWeight = FontWeight.Bold,
                                                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
                                                                )
                                                            }
                                                            Text(
                                                                text = student.email,
                                                                fontSize = 11.sp,
                                                                color = Color.White.copy(alpha = 0.5f),
                                                                maxLines = 1
                                                            )
                                                        }
                                                    }
                                                }

                                                // "View Profile" Icon Button
                                                IconButton(
                                                    onClick = { selectedStudentForProfile = student },
                                                    modifier = Modifier.size(32.dp)
                                                ) {
                                                    Text("ℹ️", fontSize = 16.sp)
                                                }
                                            }

                                            Spacer(modifier = Modifier.height(10.dp))

                                            // ── Real-Time Status & Hardware Pills
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                // Live Online / Offline identification badge
                                                Surface(
                                                    color = when {
                                                        student.isOnline && student.isFaceVerified -> Color(0xFF10B981).copy(alpha = 0.2f)
                                                        student.isOnline -> Color(0xFFF59E0B).copy(alpha = 0.2f)
                                                        else -> Color.White.copy(alpha = 0.08f)
                                                    },
                                                    shape = RoundedCornerShape(8.dp),
                                                    border = androidx.compose.foundation.BorderStroke(
                                                        1.dp,
                                                        when {
                                                            student.isOnline && student.isFaceVerified -> Color(0xFF10B981).copy(alpha = 0.5f)
                                                            student.isOnline -> Color(0xFFF59E0B).copy(alpha = 0.5f)
                                                            else -> Color.White.copy(alpha = 0.15f)
                                                        }
                                                    )
                                                ) {
                                                    Row(
                                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                                                        verticalAlignment = Alignment.CenterVertically,
                                                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                                                    ) {
                                                        Text(
                                                            text = when {
                                                                student.isOnline && student.isFaceVerified -> "🟢 Live • Face Verified"
                                                                student.isOnline -> "🟡 Away (No Face)"
                                                                else -> "⚪ Offline"
                                                            },
                                                            fontSize = 10.sp,
                                                            fontWeight = FontWeight.Bold,
                                                            color = when {
                                                                student.isOnline && student.isFaceVerified -> Color(0xFF34D399)
                                                                student.isOnline -> Color(0xFFFBBF24)
                                                                else -> Color(0xFF94A3B8)
                                                            }
                                                        )
                                                    }
                                                }

                                                // Attendance Rate
                                                Text(
                                                    text = "📊 ${student.attendanceRate}% Attendance",
                                                    fontSize = 10.sp,
                                                    fontWeight = FontWeight.SemiBold,
                                                    color = Color.White.copy(alpha = 0.7f)
                                                )

                                                // Feed indicators
                                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                    Text(if (student.isMicMuted) "🔇" else "🎤", fontSize = 12.sp)
                                                    Text(if (student.isVideoOff) "📷❌" else "📹", fontSize = 12.sp)
                                                }
                                            }

                                            // Instructor Moderation Actions
                                            if (isInstructor) {
                                                Spacer(modifier = Modifier.height(8.dp))
                                                Row(
                                                    modifier = Modifier.fillMaxWidth(),
                                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                                ) {
                                                    FilledTonalButton(
                                                        onClick = {
                                                            val idx = liveStudents.indexOfFirst { it.id == student.id }
                                                            if (idx != -1) {
                                                                val updated = student.copy(isMicMuted = !student.isMicMuted)
                                                                liveStudents[idx] = updated
                                                                controlFeedback = "${if (updated.isMicMuted) "🔇 Muted" else "🔊 Unmuted"} ${student.name}"
                                                                scope.launch {
                                                                    EduVerseApi.sendLiveControl(if (updated.isMicMuted) "MUTE" else "UNMUTE", student.id, roomName)
                                                                }
                                                            }
                                                        },
                                                        colors = ButtonDefaults.filledTonalButtonColors(
                                                            containerColor = if (student.isMicMuted) Color(0xFFEF4444).copy(alpha = 0.2f) else Color.White.copy(alpha = 0.08f)
                                                        ),
                                                        shape = RoundedCornerShape(8.dp),
                                                        modifier = Modifier.weight(1f),
                                                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
                                                    ) {
                                                        Text(
                                                            text = if (student.isMicMuted) "Unmute" else "Mute",
                                                            fontSize = 11.sp,
                                                            color = if (student.isMicMuted) Color(0xFFF87171) else Color.White
                                                        )
                                                    }

                                                    FilledTonalButton(
                                                        onClick = {
                                                            val idx = liveStudents.indexOfFirst { it.id == student.id }
                                                            if (idx != -1) {
                                                                val updated = student.copy(isVideoOff = !student.isVideoOff)
                                                                liveStudents[idx] = updated
                                                                controlFeedback = "${if (updated.isVideoOff) "📷 Video Stopped" else "📹 Video Allowed"} for ${student.name}"
                                                                scope.launch {
                                                                    EduVerseApi.sendLiveControl(if (updated.isVideoOff) "VIDEO_OFF" else "VIDEO_ON", student.id, roomName)
                                                                }
                                                            }
                                                        },
                                                        colors = ButtonDefaults.filledTonalButtonColors(
                                                            containerColor = if (student.isVideoOff) Color(0xFFEF4444).copy(alpha = 0.2f) else Color.White.copy(alpha = 0.08f)
                                                        ),
                                                        shape = RoundedCornerShape(8.dp),
                                                        modifier = Modifier.weight(1f),
                                                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp)
                                                    ) {
                                                        Text(
                                                            text = if (student.isVideoOff) "Enable Cam" else "Stop Cam",
                                                            fontSize = 11.sp,
                                                            color = if (student.isVideoOff) Color(0xFFF87171) else Color.White
                                                        )
                                                    }

                                                    OutlinedButton(
                                                        onClick = {
                                                            liveStudents.remove(student)
                                                            controlFeedback = "🚫 Dismissed ${student.name} from live room."
                                                            scope.launch {
                                                                EduVerseApi.sendLiveControl("DISMISS", student.id, roomName)
                                                            }
                                                        },
                                                        shape = RoundedCornerShape(8.dp),
                                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
                                                    ) {
                                                        Text("Dismiss", fontSize = 10.sp, color = Color(0xFFEF4444))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Recognizable Student Profile & Identity Modal Dialog
                        if (selectedStudentForProfile != null) {
                            val st = selectedStudentForProfile!!
                            val (g1, g2) = getStudentAvatarGradient(st.name)
                            val initials = getStudentInitials(st.name)

                            AlertDialog(
                                onDismissRequest = { selectedStudentForProfile = null },
                                confirmButton = {
                                    TextButton(onClick = { selectedStudentForProfile = null }) {
                                        Text("Close", color = Color(0xFF8B5CF6), fontWeight = FontWeight.Bold)
                                    }
                                },
                                title = {
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Text("🎓", fontSize = 20.sp)
                                        Text("Student Identity & Live Check", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                    }
                                },
                                text = {
                                    Column(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.spacedBy(10.dp)
                                    ) {
                                        // Large Recognizable Profile Avatar
                                        Box(
                                            modifier = Modifier
                                                .size(68.dp)
                                                .clip(CircleShape)
                                                .background(Brush.linearGradient(listOf(g1, g2)))
                                                .border(3.dp, if (st.isOnline) Color(0xFF10B981) else Color(0xFF64748B), CircleShape),
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Text(
                                                text = initials,
                                                fontSize = 24.sp,
                                                fontWeight = FontWeight.ExtraBold,
                                                color = Color.White
                                            )
                                        }

                                        Text(st.name, fontWeight = FontWeight.Bold, fontSize = 17.sp, color = Color.White)
                                        Surface(
                                            color = Color(0xFF6366F1).copy(alpha = 0.2f),
                                            shape = RoundedCornerShape(6.dp)
                                        ) {
                                            Text(
                                                text = "ID: ${st.studentId} • ${st.email}",
                                                fontSize = 11.sp,
                                                color = Color(0xFFA5B4FC),
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                            )
                                        }

                                        HorizontalDivider(color = Color.White.copy(alpha = 0.1f))

                                        // Detailed verification points
                                        Column(
                                            modifier = Modifier.fillMaxWidth(),
                                            verticalArrangement = Arrangement.spacedBy(6.dp)
                                        ) {
                                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                                Text("Live Presence Status:", fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f))
                                                Text(
                                                    text = if (st.isOnline) "🟢 Active in Classroom" else "⚪ Offline",
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = if (st.isOnline) Color(0xFF34D399) else Color(0xFF94A3B8)
                                                )
                                            }
                                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                                Text("Biometric Face Check:", fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f))
                                                Text(
                                                    text = if (st.isFaceVerified) "✓ Face Detected & Verified" else "⚠ No Face Detected",
                                                    fontSize = 12.sp,
                                                    fontWeight = FontWeight.Bold,
                                                    color = if (st.isFaceVerified) Color(0xFF34D399) else Color(0xFFFBBF24)
                                                )
                                            }
                                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                                Text("Microphone Feed:", fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f))
                                                Text(
                                                    text = if (st.isMicMuted) "🔇 Muted" else "🎤 Active Speaker",
                                                    fontSize = 12.sp,
                                                    color = Color.White
                                                )
                                            }
                                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                                Text("Video Stream:", fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f))
                                                Text(
                                                    text = if (st.isVideoOff) "Camera Stopped" else "📹 720p HD Feed",
                                                    fontSize = 12.sp,
                                                    color = Color.White
                                                )
                                            }
                                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                                Text("Attendance Record:", fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f))
                                                Text("${st.attendanceRate}% Historical Rate", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFFA78BFA))
                                            }
                                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                                Text("Hardware / Device:", fontSize = 12.sp, color = Color.White.copy(alpha = 0.6f))
                                                Text(st.deviceInfo, fontSize = 11.sp, color = Color.White.copy(alpha = 0.7f))
                                            }
                                        }
                                    }
                                },
                                containerColor = Color(0xFF18182E),
                                titleContentColor = Color.White,
                                textContentColor = Color.White
                            )
                        }
                    }
                }
            }

            // Bottom Interactive Floating Dock
            Surface(
                color = Color(0xFF131326),
                shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Hand Raise Toggle
                    FilledTonalButton(
                        onClick = { isHandRaised = !isHandRaised },
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = if (isHandRaised) Color(0xFFF59E0B) else Color.White.copy(alpha = 0.1f)
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(
                            text = if (isHandRaised) "✋ Raised" else "✋ Raise",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isHandRaised) Color.Black else Color.White
                        )
                    }

                    // Floating Reaction Chips with feedback
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("👏", "❤️", "💡", "🔥").forEach { emoji ->
                            Surface(
                                color = if (activeReaction == emoji) Color(0xFF8B5CF6).copy(alpha = 0.3f) else Color.White.copy(alpha = 0.08f),
                                shape = RoundedCornerShape(8.dp),
                                modifier = Modifier
                                    .padding(2.dp)
                                    .clickable {
                                        activeReaction = emoji
                                    }
                            ) {
                                Text(
                                    text = emoji,
                                    fontSize = 18.sp,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
