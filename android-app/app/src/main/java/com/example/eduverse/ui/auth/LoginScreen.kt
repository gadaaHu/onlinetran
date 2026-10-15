package com.example.eduverse.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Image
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import com.example.eduverse.R
import com.example.eduverse.data.EduVerseApi
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,
    onNavigateToRegister: () -> Unit,
    modifier: Modifier = Modifier
) {
    var email by remember { mutableStateOf("admin@eduverse.com") }
    var password by remember { mutableStateOf("Admin@123!") }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF0A0A14))
            .padding(24.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth()
        ) {
            // EduVerse Logo Icon
            Box(
                modifier = Modifier
                    .size(92.dp)
                    .background(Color.White, shape = CircleShape)
                    .padding(8.dp),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    painter = painterResource(id = R.drawable.app_logo),
                    contentDescription = "EduVerse DW Logo",
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(CircleShape)
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            Text(
                text = "Welcome to EduVerse",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Text(
                text = "Modern Online Training & Live Class",
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.6f)
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Email Input
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email or admin") },
                leadingIcon = { Text("✉️", fontSize = 16.sp) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = Color(0xFF8B5CF6),
                    unfocusedBorderColor = Color.White.copy(alpha = 0.2f),
                    focusedLabelColor = Color(0xFF8B5CF6),
                    unfocusedLabelColor = Color.White.copy(alpha = 0.6f)
                ),
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Password Input
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password") },
                leadingIcon = { Text("🔒", fontSize = 16.sp) },
                visualTransformation = PasswordVisualTransformation(),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = Color(0xFF8B5CF6),
                    unfocusedBorderColor = Color.White.copy(alpha = 0.2f),
                    focusedLabelColor = Color(0xFF8B5CF6),
                    unfocusedLabelColor = Color.White.copy(alpha = 0.6f)
                ),
                shape = RoundedCornerShape(12.dp)
            )

            Spacer(modifier = Modifier.height(10.dp))

            var serverUrl by remember { mutableStateOf(EduVerseApi.baseUrl) }
            var showServerConfig by remember { mutableStateOf(false) }
            var connectionStatus by remember { mutableStateOf<String?>(null) }
            var isTestingConnection by remember { mutableStateOf(false) }

            // Quick Actions row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = { showServerConfig = !showServerConfig; connectionStatus = null }) {
                    Text(
                        text = if (showServerConfig) "▲ Hide Server" else "⚙️ Server URL",
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.6f)
                    )
                }
                TextButton(
                    onClick = {
                        email = "admin@eduverse.com"
                        password = "Admin@123!"
                    }
                ) {
                    Text(
                        text = "⚡ Autofill Admin",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF8B5CF6)
                    )
                }
            }

            if (showServerConfig) {
                Spacer(modifier = Modifier.height(6.dp))
                OutlinedTextField(
                    value = serverUrl,
                    onValueChange = {
                        serverUrl = it
                        EduVerseApi.baseUrl = it.trim()
                        connectionStatus = null
                    },
                    label = { Text("API URL") },
                    placeholder = { Text("http://localhost:5083/api", color = Color.White.copy(alpha = 0.3f)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedBorderColor = Color(0xFF8B5CF6),
                        unfocusedBorderColor = Color.White.copy(alpha = 0.2f),
                        focusedLabelColor = Color(0xFF8B5CF6),
                        unfocusedLabelColor = Color.White.copy(alpha = 0.6f)
                    ),
                    shape = RoundedCornerShape(12.dp)
                )

                // Quick URL preset buttons
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    val presets = listOf(
                        "USB" to "http://localhost:5083/api",
                        "LAN" to "http://192.168.100.107:5083/api",
                        "Emulator" to "http://10.0.2.2:5083/api"
                    )
                    presets.forEach { (label, url) ->
                        val isSelected = serverUrl.trim() == url
                        Surface(
                            onClick = {
                                serverUrl = url
                                EduVerseApi.baseUrl = url
                                connectionStatus = null
                            },
                            shape = RoundedCornerShape(8.dp),
                            color = if (isSelected) Color(0xFF8B5CF6).copy(alpha = 0.25f) else Color.White.copy(alpha = 0.07f),
                            border = androidx.compose.foundation.BorderStroke(
                                1.dp,
                                if (isSelected) Color(0xFF8B5CF6) else Color.White.copy(alpha = 0.15f)
                            ),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(
                                text = label,
                                color = if (isSelected) Color(0xFFA78BFA) else Color.White.copy(alpha = 0.6f),
                                fontSize = 11.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center
                            )
                        }
                    }
                }

                // Test connection button
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Button(
                        onClick = {
                            isTestingConnection = true
                            connectionStatus = null
                            scope.launch {
                                try {
                                    val testUrl = java.net.URL("${EduVerseApi.baseUrl}/courses?page=1&pageSize=1")
                                    val conn = testUrl.openConnection() as java.net.HttpURLConnection
                                    conn.connectTimeout = 4000
                                    conn.readTimeout = 4000
                                    val code = conn.responseCode
                                    connectionStatus = if (code in 200..499) "✅ Connected! (HTTP $code)" else "❌ Server error (HTTP $code)"
                                } catch (e: Exception) {
                                    connectionStatus = "❌ Can't reach server. Try USB preset."
                                } finally {
                                    isTestingConnection = false
                                }
                            }
                        },
                        enabled = !isTestingConnection,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1E1E3F)),
                        shape = RoundedCornerShape(10.dp),
                        modifier = Modifier.weight(1f).height(40.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        if (isTestingConnection) {
                            CircularProgressIndicator(color = Color(0xFF8B5CF6), modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        } else {
                            Text("Test Connection", fontSize = 12.sp, color = Color(0xFF8B5CF6))
                        }
                    }
                    connectionStatus?.let { status ->
                        Text(
                            text = status,
                            fontSize = 11.sp,
                            color = if (status.startsWith("✅")) Color(0xFF10B981) else Color(0xFFF87171),
                            modifier = Modifier.weight(1.2f)
                        )
                    }
                }

                // USB tip
                Spacer(modifier = Modifier.height(4.dp))
                Surface(
                    color = Color(0xFF1E293B),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "💡 USB mode: plug in phone → run  adb reverse tcp:5083 tcp:5083  → use USB preset above",
                        fontSize = 10.sp,
                        color = Color.White.copy(alpha = 0.45f),
                        modifier = Modifier.padding(10.dp),
                        lineHeight = 14.sp
                    )
                }
                Spacer(modifier = Modifier.height(6.dp))
            }

            if (errorMessage != null) {
                Spacer(modifier = Modifier.height(12.dp))
                val isPending = errorMessage?.contains("pending", ignoreCase = true) == true
                Surface(
                    color = if (isPending) Color(0xFFF59E0B).copy(alpha = 0.15f) else Color(0xFFEF4444).copy(alpha = 0.15f),
                    shape = RoundedCornerShape(10.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        1.dp,
                        if (isPending) Color(0xFFF59E0B).copy(alpha = 0.4f) else Color(0xFFEF4444).copy(alpha = 0.4f)
                    ),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(if (isPending) "⏳" else "⚠️", fontSize = 18.sp)
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = errorMessage ?: "",
                            color = if (isPending) Color(0xFFFBBF24) else Color(0xFFF87171),
                            fontSize = 13.sp,
                            lineHeight = 18.sp
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Sign In Button
            Button(
                onClick = {
                    isLoading = true
                    errorMessage = null
                    scope.launch {
                        val trimmedEmail = email.trim()
                        val finalEmail = if (trimmedEmail.equals("admin", ignoreCase = true)) "admin@eduverse.com" else trimmedEmail
                        val res = EduVerseApi.login(finalEmail, password)
                        isLoading = false
                        res.onSuccess {
                            onLoginSuccess()
                        }.onFailure { err ->
                            errorMessage = err.message ?: "Login failed. Check server connection."
                        }
                    }
                },
                enabled = !isLoading && email.isNotBlank() && password.isNotBlank(),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color(0xFF8B5CF6)
                )
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        color = Color.White,
                        modifier = Modifier.size(22.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text = "Sign In",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Link to Register as Student
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "New student?",
                    fontSize = 13.sp,
                    color = Color.White.copy(alpha = 0.6f)
                )
                TextButton(onClick = onNavigateToRegister) {
                    Text(
                        text = "Register as Student",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFFA78BFA)
                    )
                }
            }
        }
    }
}
