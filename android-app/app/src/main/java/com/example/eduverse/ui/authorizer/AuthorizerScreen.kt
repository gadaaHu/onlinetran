package com.example.eduverse.ui.authorizer

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.eduverse.data.EduVerseApi
import com.example.eduverse.data.StudentSummary
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthorizerScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    var students by remember { mutableStateOf<List<StudentSummary>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var actionMessage by remember { mutableStateOf<String?>(null) }
    var filterQuery by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    val bg = MaterialTheme.colorScheme.background
    val surface = MaterialTheme.colorScheme.surface
    val onSurface = MaterialTheme.colorScheme.onSurface
    val primary = MaterialTheme.colorScheme.primary

    fun loadStudents() {
        isLoading = true
        scope.launch {
            val res = EduVerseApi.getStudents()
            isLoading = false
            res.onSuccess {
                students = it
            }.onFailure { err ->
                actionMessage = "Error loading: ${err.message}"
            }
        }
    }

    LaunchedEffect(Unit) {
        loadStudents()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "🛡️ Student Authorization",
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Bold,
                            color = onSurface
                        )
                        Text(
                            text = "Confirm & approve student access",
                            fontSize = 11.sp,
                            color = onSurface.copy(alpha = 0.6f)
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Text("←", fontSize = 22.sp, color = onSurface)
                    }
                },
                actions = {
                    IconButton(onClick = { loadStudents() }) {
                        Text("🔄", fontSize = 18.sp)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = surface)
            )
        },
        containerColor = bg,
        modifier = modifier
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            // Summary count cards
            val pendingCount = students.count { !it.isConfirmed }
            val approvedCount = students.count { it.isConfirmed }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Surface(
                    color = Color(0xFFF59E0B).copy(alpha = 0.15f),
                    shape = RoundedCornerShape(12.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFF59E0B).copy(alpha = 0.3f)),
                    modifier = Modifier.weight(1f)
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text("Pending Approval", fontSize = 11.sp, color = Color(0xFFFBBF24))
                        Text("$pendingCount", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = onSurface)
                    }
                }

                Surface(
                    color = Color(0xFF10B981).copy(alpha = 0.15f),
                    shape = RoundedCornerShape(12.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF10B981).copy(alpha = 0.3f)),
                    modifier = Modifier.weight(1f)
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text("Authorized Students", fontSize = 11.sp, color = Color(0xFF34D399))
                        Text("$approvedCount", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = onSurface)
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Search filter
            OutlinedTextField(
                value = filterQuery,
                onValueChange = { filterQuery = it },
                placeholder = { Text("Filter by student name or email...", color = onSurface.copy(alpha = 0.45f), fontSize = 13.sp) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = onSurface,
                    unfocusedTextColor = onSurface,
                    focusedBorderColor = primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)
                )
            )

            if (actionMessage != null) {
                Spacer(modifier = Modifier.height(8.dp))
                Surface(
                    color = primary.copy(alpha = 0.15f),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = actionMessage ?: "",
                        color = onSurface,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(8.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            if (isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = primary)
                }
            } else {
                val filtered = students.filter {
                    filterQuery.isBlank() ||
                    it.fullName.contains(filterQuery, ignoreCase = true) ||
                    it.email.contains(filterQuery, ignoreCase = true)
                }

                if (filtered.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("No registered students found.", color = onSurface.copy(alpha = 0.5f), fontSize = 14.sp)
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        items(filtered, key = { it.id }) { s ->
                            Card(
                                shape = RoundedCornerShape(14.dp),
                                colors = CardDefaults.cardColors(containerColor = surface),
                                border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.25f)),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(modifier = Modifier.padding(14.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(
                                                text = s.fullName.ifBlank { s.email },
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 15.sp,
                                                color = onSurface
                                            )
                                            Text(
                                                text = s.email,
                                                fontSize = 12.sp,
                                                color = onSurface.copy(alpha = 0.6f)
                                            )
                                        }

                                        // Status badge
                                        Surface(
                                            color = if (s.isConfirmed) Color(0xFF10B981).copy(alpha = 0.2f) else Color(0xFFF59E0B).copy(alpha = 0.2f),
                                            shape = RoundedCornerShape(8.dp),
                                            border = androidx.compose.foundation.BorderStroke(
                                                1.dp,
                                                if (s.isConfirmed) Color(0xFF10B981) else Color(0xFFF59E0B)
                                            )
                                        ) {
                                            Text(
                                                text = if (s.isConfirmed) "AUTHORIZED" else "PENDING",
                                                fontSize = 10.sp,
                                                fontWeight = FontWeight.Bold,
                                                color = if (s.isConfirmed) Color(0xFF34D399) else Color(0xFFFBBF24),
                                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                                            )
                                        }
                                    }

                                    Spacer(modifier = Modifier.height(12.dp))

                                    // Action buttons for authorizer
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.End,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        if (!s.isConfirmed) {
                                            Button(
                                                onClick = {
                                                    scope.launch {
                                                        val res = EduVerseApi.confirmStudent(s.id)
                                                        res.onSuccess { msg ->
                                                            actionMessage = "✅ $msg"
                                                            loadStudents()
                                                        }.onFailure { err ->
                                                            actionMessage = "❌ ${err.message}"
                                                        }
                                                    }
                                                },
                                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
                                                shape = RoundedCornerShape(8.dp),
                                                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 6.dp)
                                            ) {
                                                Text("✅ Confirm Student", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                            }
                                        } else {
                                            OutlinedButton(
                                                onClick = {
                                                    scope.launch {
                                                        val res = EduVerseApi.rejectStudent(s.id)
                                                        res.onSuccess { msg ->
                                                            actionMessage = "⚠️ $msg"
                                                            loadStudents()
                                                        }.onFailure { err ->
                                                            actionMessage = "❌ ${err.message}"
                                                        }
                                                    }
                                                },
                                                shape = RoundedCornerShape(8.dp),
                                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                                            ) {
                                                Text("Revoke Access", fontSize = 11.sp, color = Color(0xFFF87171))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
