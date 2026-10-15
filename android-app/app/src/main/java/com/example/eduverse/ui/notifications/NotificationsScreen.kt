package com.example.eduverse.ui.notifications

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.eduverse.data.EduVerseApi
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

// ── Data ──────────────────────────────────────────────────────────────────────
data class AppNotification(
    val id: Int,
    val title: String,
    val message: String,
    val type: String,
    val isRead: Boolean,
    val actionUrl: String?,
    val createdAt: String
)

// ── Screen ────────────────────────────────────────────────────────────────────
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scope = rememberCoroutineScope()
    var notifications by remember { mutableStateOf<List<AppNotification>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var unreadOnly by remember { mutableStateOf(false) }
    var errorMsg by remember { mutableStateOf<String?>(null) }

    val bg = MaterialTheme.colorScheme.background
    val surface = MaterialTheme.colorScheme.surface
    val accent = MaterialTheme.colorScheme.primary
    val onSurface = MaterialTheme.colorScheme.onSurface

    // ── helpers ──
    fun loadNotifications() {
        scope.launch {
            loading = true
            errorMsg = null
            var success = false
            var lastErr: String? = null
            val token = EduVerseApi.getAuthToken()

            for (base in EduVerseApi.getCandidateBaseUrls()) {
                try {
                    val baseWithApi = if (base.endsWith("/api")) base else "${base.trimEnd('/')}/api"
                    val endpoint = "${baseWithApi.trimEnd('/')}/notifications${if (unreadOnly) "?unreadOnly=true" else ""}"
                    val url = URL(endpoint)
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "GET"
                        setRequestProperty("Accept", "application/json")
                        if (!token.isNullOrBlank()) {
                            setRequestProperty("Authorization", "Bearer $token")
                        }
                        connectTimeout = 4000
                        readTimeout = 4000
                    }
                    if (conn.responseCode in 200..299) {
                        EduVerseApi.baseUrl = base
                        val body = conn.inputStream.bufferedReader().use { it.readText() }
                        // Backend returns { total, unreadCount, notifications:[...] } envelope
                        val array = if (body.trim().startsWith("[")) {
                            JSONArray(body)
                        } else {
                            val envelope = JSONObject(body)
                            // Try "notifications" key first (backend envelope), then bare array fallback
                            envelope.optJSONArray("notifications")
                                ?: envelope.optJSONArray("items")
                                ?: JSONArray()
                        }
                        val list = mutableListOf<AppNotification>()
                        for (i in 0 until array.length()) {
                            val obj = array.getJSONObject(i)
                            list.add(
                                AppNotification(
                                    id = obj.getInt("id"),
                                    title = obj.getString("title"),
                                    message = obj.getString("message"),
                                    type = obj.optString("type", "info"),
                                    isRead = obj.optBoolean("isRead", false),
                                    actionUrl = if (obj.isNull("actionUrl")) null else obj.optString("actionUrl"),
                                    createdAt = obj.optString("createdAt", "")
                                )
                            )
                        }
                        notifications = list
                        success = true
                        break
                    } else {
                        lastErr = "Server error: ${conn.responseCode}"
                    }
                } catch (e: Exception) {
                    lastErr = e.localizedMessage ?: "Failed to connect"
                }
            }

            if (!success) {
                errorMsg = lastErr ?: "Failed to connect"
            }
            loading = false
        }
    }

    fun markRead(id: Int) {
        scope.launch {
            val token = EduVerseApi.getAuthToken()
            for (base in EduVerseApi.getCandidateBaseUrls()) {
                try {
                    val baseWithApi = if (base.endsWith("/api")) base else "${base.trimEnd('/')}/api"
                    val url = URL("${baseWithApi.trimEnd('/')}/notifications/$id/read")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        if (!token.isNullOrBlank()) setRequestProperty("Authorization", "Bearer $token")
                        connectTimeout = 4000
                        readTimeout = 4000
                    }
                    if (conn.responseCode in 200..299) {
                        EduVerseApi.baseUrl = base
                        notifications = notifications.map {
                            if (it.id == id) it.copy(isRead = true) else it
                        }
                        break
                    }
                } catch (_: Exception) {}
            }
        }
    }

    fun markAllRead() {
        scope.launch {
            val token = EduVerseApi.getAuthToken()
            for (base in EduVerseApi.getCandidateBaseUrls()) {
                try {
                    val baseWithApi = if (base.endsWith("/api")) base else "${base.trimEnd('/')}/api"
                    val url = URL("${baseWithApi.trimEnd('/')}/notifications/read-all")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        if (!token.isNullOrBlank()) setRequestProperty("Authorization", "Bearer $token")
                        connectTimeout = 4000
                        readTimeout = 4000
                    }
                    if (conn.responseCode in 200..299) {
                        EduVerseApi.baseUrl = base
                        notifications = notifications.map { it.copy(isRead = true) }
                        break
                    }
                } catch (_: Exception) {}
            }
        }
    }

    LaunchedEffect(unreadOnly) { loadNotifications() }

    val unreadCount = notifications.count { !it.isRead }

    Scaffold(
        containerColor = bg,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(containerColor = surface),
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Text("←", fontSize = 22.sp, color = onSurface)
                    }
                },
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "Notifications",
                            color = onSurface,
                            fontWeight = FontWeight.Bold,
                            fontSize = 20.sp
                        )
                        if (unreadCount > 0) {
                            Spacer(Modifier.width(8.dp))
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(accent)
                                    .padding(horizontal = 8.dp, vertical = 2.dp)
                            ) {
                                Text("$unreadCount", color = Color.White,
                                    fontSize = 11.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                },
                actions = {
                    if (unreadCount > 0) {
                        TextButton(onClick = { markAllRead() }) {
                            Text("Mark all read", color = accent, fontSize = 12.sp)
                        }
                    }
                    IconButton(onClick = { loadNotifications() }) {
                        Text("🔄", fontSize = 18.sp)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Filter chips
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterPill(label = "All", selected = !unreadOnly) { unreadOnly = false }
                FilterPill(label = "Unread", selected = unreadOnly) { unreadOnly = true }
            }

            when {
                loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = accent)
                }
                errorMsg != null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("⚠️", fontSize = 42.sp)
                        Spacer(Modifier.height(12.dp))
                        Text(errorMsg!!, color = onSurface.copy(alpha = 0.7f))
                        Spacer(Modifier.height(12.dp))
                        Button(onClick = { loadNotifications() },
                            colors = ButtonDefaults.buttonColors(containerColor = accent)) {
                            Text("Retry")
                        }
                    }
                }
                notifications.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("🔔", fontSize = 48.sp)
                        Spacer(Modifier.height(12.dp))
                        Text("No notifications", color = onSurface,
                            fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text(
                            if (unreadOnly) "You're all caught up!" else "Notifications appear here",
                            color = onSurface.copy(alpha = 0.5f), fontSize = 13.sp
                        )
                    }
                }
                else -> LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    itemsIndexed(notifications, key = { _, n -> n.id }) { _, notif ->
                        NotificationCard(
                            notification = notif,
                            surface = surface,
                            accent = accent,
                            onMarkRead = { if (!notif.isRead) markRead(notif.id) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterPill(label: String, selected: Boolean, onClick: () -> Unit) {
    val accent = MaterialTheme.colorScheme.primary
    val surface = MaterialTheme.colorScheme.surfaceVariant
    val animBg by animateColorAsState(
        targetValue = if (selected) accent else surface,
        animationSpec = tween(200)
    )
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(animBg)
            .border(1.dp,
                if (selected) accent else MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                RoundedCornerShape(20.dp))
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 6.dp)
    ) {
        Text(
            label,
            color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
            fontSize = 13.sp
        )
    }
}

@Composable
private fun NotificationCard(
    notification: AppNotification,
    surface: Color,
    accent: Color,
    onMarkRead: () -> Unit
) {
    val typeColor = when (notification.type) {
        "success" -> Color(0xFF10B981)
        "warning" -> Color(0xFFF59E0B)
        "live"    -> Color(0xFFEF4444)
        else      -> accent
    }
    val typeEmoji = when (notification.type) {
        "success" -> "✅"
        "warning" -> "⚠️"
        "live"    -> "🔴"
        else      -> "📢"
    }

    val onSurface = MaterialTheme.colorScheme.onSurface
    val borderColor = if (notification.isRead)
        MaterialTheme.colorScheme.outline.copy(alpha = 0.15f) else typeColor.copy(alpha = 0.35f)

    val bgColor = if (notification.isRead) surface else MaterialTheme.colorScheme.surfaceVariant

    val visible = remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible.value = true }

    AnimatedVisibility(
        visible = visible.value,
        enter = fadeIn() + slideInVertically(initialOffsetY = { it / 8 })
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(enabled = !notification.isRead) { onMarkRead() },
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = bgColor),
            border = BorderStroke(1.dp, borderColor)
        ) {
            Row(
                modifier = Modifier.padding(14.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Icon bubble
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(typeColor.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(typeEmoji, fontSize = 20.sp)
                }

                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            notification.title,
                            color = if (notification.isRead) onSurface.copy(alpha = 0.65f) else onSurface,
                            fontWeight = if (notification.isRead) FontWeight.Normal else FontWeight.Bold,
                            fontSize = 14.sp,
                            modifier = Modifier.weight(1f)
                        )
                        if (!notification.isRead) {
                            Box(
                                Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(typeColor)
                            )
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        notification.message,
                        color = if (notification.isRead)
                            onSurface.copy(alpha = 0.45f) else onSurface.copy(alpha = 0.75f),
                        fontSize = 13.sp
                    )
                    Spacer(Modifier.height(6.dp))
                    Text(
                        timeAgo(notification.createdAt),
                        color = onSurface.copy(alpha = 0.4f),
                        fontSize = 11.sp
                    )
                }
            }
        }
    }
}

private fun timeAgo(isoDate: String): String {
    return try {
        val zdt = ZonedDateTime.parse(isoDate, DateTimeFormatter.ISO_DATE_TIME)
        val now = ZonedDateTime.now()
        val mins = ChronoUnit.MINUTES.between(zdt, now)
        when {
            mins < 1    -> "just now"
            mins < 60   -> "${mins}m ago"
            mins < 1440 -> "${mins / 60}h ago"
            else        -> "${mins / 1440}d ago"
        }
    } catch (_: Exception) { "" }
}
