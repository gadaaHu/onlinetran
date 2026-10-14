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
import com.example.eduverse.data.EduVerseApi
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,
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
                    .size(76.dp)
                    .background(
                        brush = Brush.linearGradient(
                            listOf(Color(0xFF8B5CF6), Color(0xFF6366F1))
                        ),
                        shape = CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "🎓",
                    fontSize = 36.sp
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

            // Quick Demo Admin Autofill Button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(
                    onClick = {
                        email = "admin@eduverse.com"
                        password = "Admin@123!"
                    }
                ) {
                    Text(
                        text = "⚡ Autofill Admin Login",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color(0xFF8B5CF6)
                    )
                }
            }

            if (errorMessage != null) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = Color(0xFFEF4444).copy(alpha = 0.15f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = errorMessage ?: "",
                        color = Color(0xFFF87171),
                        fontSize = 13.sp,
                        modifier = Modifier.padding(10.dp)
                    )
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
        }
    }
}
