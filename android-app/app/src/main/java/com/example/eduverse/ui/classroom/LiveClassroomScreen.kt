package com.example.eduverse.ui.classroom

import android.annotation.SuppressLint
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.example.eduverse.data.EduVerseApi

@OptIn(ExperimentalMaterial3Api::class)
@SuppressLint("SetJavaScriptEnabled")
@Composable
fun AndroidLiveClassroomScreen(
    roomName: String,
    lessonTitle: String,
    onLeaveClass: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isHandRaised by remember { mutableStateOf(false) }
    val user = EduVerseApi.currentSession
    val displayName = user?.fullName ?: "Student"

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
            // Live Video Stage via embedded WebView
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                AndroidView(
                    factory = { ctx ->
                        WebView(ctx).apply {
                            settings.javaScriptEnabled = true
                            settings.domStorageEnabled = true
                            settings.mediaPlaybackRequiresUserGesture = false
                            settings.allowFileAccess = true
                            settings.cacheMode = WebSettings.LOAD_DEFAULT

                            webChromeClient = object : WebChromeClient() {
                                override fun onPermissionRequest(request: PermissionRequest) {
                                    // Grant camera & microphone permissions to Jitsi Web
                                    request.grant(request.resources)
                                }
                            }
                            webViewClient = WebViewClient()
                            loadUrl(jitsiUrl)
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )
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
                        .padding(horizontal = 16.dp, vertical = 12.dp),
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
                            text = if (isHandRaised) "✋ Hand Raised" else "✋ Raise Hand",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (isHandRaised) Color.Black else Color.White
                        )
                    }

                    // Floating Reaction Chips
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("👏", "❤️", "💡", "🔥").forEach { emoji ->
                            Surface(
                                color = Color.White.copy(alpha = 0.08f),
                                shape = RoundedCornerShape(8.dp),
                                modifier = Modifier.padding(2.dp)
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
