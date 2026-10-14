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
import com.example.eduverse.data.EduVerseApi

enum class ClassroomTab {
    VIDEO, WHITEBOARD, CHAT
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
            // Classroom Mode Tabs
            TabRow(
                selectedTabIndex = selectedTab.ordinal,
                containerColor = Color(0xFF131326),
                contentColor = Color(0xFF8B5CF6)
            ) {
                Tab(
                    selected = selectedTab == ClassroomTab.VIDEO,
                    onClick = { selectedTab = ClassroomTab.VIDEO },
                    text = { Text("📹 Video Stage", fontSize = 13.sp, fontWeight = FontWeight.SemiBold) }
                )
                Tab(
                    selected = selectedTab == ClassroomTab.WHITEBOARD,
                    onClick = { selectedTab = ClassroomTab.WHITEBOARD },
                    text = { Text("🎨 Whiteboard", fontSize = 13.sp, fontWeight = FontWeight.SemiBold) }
                )
                Tab(
                    selected = selectedTab == ClassroomTab.CHAT,
                    onClick = { selectedTab = ClassroomTab.CHAT },
                    text = { Text("💬 Live Chat", fontSize = 13.sp, fontWeight = FontWeight.SemiBold) }
                )
            }

            // Main Content Area
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                when (selectedTab) {
                    ClassroomTab.VIDEO -> {
                        Box(modifier = Modifier.fillMaxSize()) {
                            AndroidView(
                                factory = { ctx ->
                                    WebView(ctx).apply {
                                        // Desktop user-agent prevents Jitsi from displaying mobile app download splash
                                        settings.userAgentString =
                                            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
                                        settings.javaScriptEnabled = true
                                        settings.domStorageEnabled = true
                                        settings.databaseEnabled = true
                                        settings.mediaPlaybackRequiresUserGesture = false
                                        settings.allowFileAccess = true
                                        settings.cacheMode = WebSettings.LOAD_DEFAULT

                                        webChromeClient = object : WebChromeClient() {
                                            override fun onPermissionRequest(request: PermissionRequest) {
                                                request.grant(request.resources)
                                            }
                                        }

                                        webViewClient = object : WebViewClient() {
                                            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                                                isWebLoading = true
                                                webLoadError = null
                                            }

                                            override fun onPageFinished(view: WebView?, url: String?) {
                                                isWebLoading = false
                                            }

                                            override fun onReceivedError(
                                                view: WebView?,
                                                request: WebResourceRequest?,
                                                error: WebResourceError?
                                            ) {
                                                if (request?.isForMainFrame == true) {
                                                    isWebLoading = false
                                                    webLoadError = "Unable to connect to live stream. If offline, use Whiteboard or Chat."
                                                }
                                            }
                                        }
                                        loadUrl(jitsiUrl)
                                    }
                                },
                                modifier = Modifier.fillMaxSize()
                            )

                            if (isWebLoading) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(Color(0xFF0A0A14)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        CircularProgressIndicator(color = Color(0xFF8B5CF6))
                                        Spacer(modifier = Modifier.height(16.dp))
                                        Text(
                                            text = "Connecting to Live Stream...",
                                            color = Color.White,
                                            fontSize = 14.sp
                                        )
                                        Text(
                                            text = "Room: $roomName",
                                            color = Color.White.copy(alpha = 0.5f),
                                            fontSize = 12.sp
                                        )
                                    }
                                }
                            }

                            if (webLoadError != null) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(Color(0xFF0F0F1D))
                                        .padding(24.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text("📡", fontSize = 48.sp)
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Text(
                                            text = "Live Stream Notice",
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White,
                                            fontSize = 16.sp
                                        )
                                        Spacer(modifier = Modifier.height(6.dp))
                                        Text(
                                            text = webLoadError ?: "",
                                            color = Color.White.copy(alpha = 0.7f),
                                            fontSize = 13.sp,
                                            lineHeight = 18.sp
                                        )
                                        Spacer(modifier = Modifier.height(20.dp))
                                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                            Button(
                                                onClick = { selectedTab = ClassroomTab.WHITEBOARD },
                                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8B5CF6))
                                            ) {
                                                Text("🎨 Open Whiteboard")
                                            }
                                            OutlinedButton(
                                                onClick = { selectedTab = ClassroomTab.CHAT }
                                            ) {
                                                Text("💬 Open Chat", color = Color.White)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

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
