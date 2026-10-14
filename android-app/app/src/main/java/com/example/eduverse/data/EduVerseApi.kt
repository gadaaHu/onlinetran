package com.example.eduverse.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

data class UserSession(
    val token: String,
    val email: String,
    val fullName: String,
    val roles: List<String>
)

data class Course(
    val id: Int,
    val title: String,
    val description: String,
    val instructorName: String,
    val lessons: List<Lesson> = emptyList()
)

data class Lesson(
    val id: Int,
    val title: String,
    val isLive: Boolean,
    val meetingUrl: String?
)

object EduVerseApi {
    // 10.0.2.2 is the default Android emulator alias for localhost.
    // For physical devices on the same Wi-Fi, change to host machine's IP (e.g. 192.168.x.x)
    var baseUrl = "http://10.0.2.2:5083/api"
    var currentSession: UserSession? = null

    suspend fun login(email: String, pass: String): Result<UserSession> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/auth/login")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
                connectTimeout = 8000
                readTimeout = 8000
            }

            val json = JSONObject().apply {
                put("email", email)
                put("password", pass)
            }

            OutputStreamWriter(conn.outputStream).use { it.write(json.toString()) }

            val code = conn.responseCode
            if (code in 200..299) {
                val response = conn.inputStream.bufferedReader().use(BufferedReader::readText)
                val obj = JSONObject(response)
                val rolesArray = obj.optJSONArray("roles") ?: JSONArray()
                val roles = mutableListOf<String>()
                for (i in 0 until rolesArray.length()) {
                    roles.add(rolesArray.getString(i))
                }

                val session = UserSession(
                    token = obj.getString("token"),
                    email = obj.getString("email"),
                    fullName = obj.optString("fullName", "User"),
                    roles = roles
                )
                currentSession = session
                Result.success(session)
            } else {
                val err = conn.errorStream?.bufferedReader()?.use(BufferedReader::readText) ?: "Login failed"
                val msg = try { JSONObject(err).optString("message", "Invalid credentials") } catch (_: Exception) { "Invalid credentials ($code)" }
                Result.failure(Exception(msg))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getCourses(): Result<List<Course>> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/courses")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                currentSession?.let { setRequestProperty("Authorization", "Bearer ${it.token}") }
                connectTimeout = 8000
                readTimeout = 8000
            }

            if (conn.responseCode in 200..299) {
                val response = conn.inputStream.bufferedReader().use(BufferedReader::readText)
                val array = JSONArray(response)
                val list = mutableListOf<Course>()
                for (i in 0 until array.length()) {
                    val c = array.getJSONObject(i)
                    list.add(
                        Course(
                            id = c.getInt("id"),
                            title = c.getString("title"),
                            description = c.optString("description", "Comprehensive online curriculum."),
                            instructorName = c.optString("instructorName", "Instructor"),
                            lessons = listOf(
                                Lesson(
                                    id = 1,
                                    title = "Live Interactive Lecture",
                                    isLive = true,
                                    meetingUrl = "eduverse-class-${c.getInt("id")}"
                                )
                            )
                        )
                    )
                }
                Result.success(list)
            } else {
                // Fallback to sample courses if unauthenticated / empty
                Result.success(sampleCourses)
            }
        } catch (_: Exception) {
            Result.success(sampleCourses)
        }
    }

    private val sampleCourses = listOf(
        Course(
            id = 101,
            title = "Full-Stack Cloud & Web Engineering",
            description = "Master ASP.NET Core, Flutter, and scalable container architectures.",
            instructorName = "Alex Turner",
            lessons = listOf(
                Lesson(1, "Live System Architecture Workshop", isLive = true, meetingUrl = "eduverse-cloud-101")
            )
        ),
        Course(
            id = 102,
            title = "Modern AI & Computer Vision",
            description = "Deep learning, YOLOv8, and real-time edge streaming.",
            instructorName = "Sarah Chen",
            lessons = listOf(
                Lesson(2, "Live Neural Network Lab", isLive = true, meetingUrl = "eduverse-ai-102")
            )
        ),
        Course(
            id = 103,
            title = "Mobile Application Development with Kotlin",
            description = "Jetpack Compose, coroutines, and clean architecture.",
            instructorName = "David Miller",
            lessons = listOf(
                Lesson(3, "Live Jetpack Compose Deep Dive", isLive = true, meetingUrl = "eduverse-kotlin-103")
            )
        )
    )
}
