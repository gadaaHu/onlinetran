package com.example.eduverse.ui.courses

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.eduverse.data.Course
import com.example.eduverse.data.EduVerseApi

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseListScreen(
    onOpenClassroom: (roomName: String, lessonTitle: String) -> Unit,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier
) {
    var courses by remember { mutableStateOf<List<Course>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        val res = EduVerseApi.getCourses()
        courses = res.getOrDefault(emptyList())
        isLoading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "EduVerse Training",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        val user = EduVerseApi.currentSession
                        Text(
                            text = "Logged in as ${user?.fullName ?: "Admin"}",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    }
                },
                actions = {
                    TextButton(onClick = onLogout) {
                        Text("Logout", color = Color(0xFFF87171), fontSize = 13.sp)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF0F0F1D)
                )
            )
        },
        containerColor = Color(0xFF0A0A14),
        modifier = modifier
    ) { padding ->
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = Color(0xFF8B5CF6))
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            ) {
                item {
                    // Header Banner
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = Color(0xFF131326)
                        ),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    brush = Brush.horizontalGradient(
                                        listOf(Color(0xFF8B5CF6).copy(alpha = 0.2f), Color.Transparent)
                                    )
                                )
                                .padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Ready to learn?",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 16.sp,
                                    color = Color.White
                                )
                                Text(
                                    text = "Join live sessions or continue where you left off.",
                                    fontSize = 13.sp,
                                    color = Color.White.copy(alpha = 0.6f)
                                )
                            }
                        }
                    }
                }

                items(courses) { course ->
                    CourseCard(
                        course = course,
                        onJoinLive = { lesson ->
                            val room = lesson.meetingUrl ?: "eduverse-class-${course.id}"
                            onOpenClassroom(room, lesson.title)
                        }
                    )
                }
            }
        }
    }
}

@Composable
fun CourseCard(
    course: Course,
    onJoinLive: (lesson: com.example.eduverse.data.Lesson) -> Unit
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF141426)),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = course.title,
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    color = Color.White,
                    modifier = Modifier.weight(1f)
                )
                Surface(
                    color = Color(0xFF8B5CF6).copy(alpha = 0.2f),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = "ACTIVE",
                        color = Color(0xFF8B5CF6),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = course.description,
                fontSize = 13.sp,
                color = Color.White.copy(alpha = 0.6f),
                maxLines = 2
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "Instructor: ${course.instructorName}",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.4f)
            )

            Spacer(modifier = Modifier.height(14.dp))

            // Live Class Button
            val liveLesson = course.lessons.firstOrNull { it.isLive }
            if (liveLesson != null) {
                Button(
                    onClick = { onJoinLive(liveLesson) },
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = "📹 Join Live Virtual Classroom",
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = Color.White
                    )
                }
            }
        }
    }
}
