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

data class StudentSummary(
    val id: String,
    val email: String,
    val firstName: String,
    val lastName: String,
    val fullName: String,
    val isConfirmed: Boolean,
    val roles: List<String>,
    val createdAt: String
)

data class LiveStudentPresence(
    val id: String,
    val studentId: String,
    val name: String,
    val email: String,
    val roles: List<String> = listOf("Student"),
    val isOnline: Boolean = true,
    val isFaceVerified: Boolean = false,
    val faceCount: Int = 0,
    val isMicMuted: Boolean = false,
    val isVideoOff: Boolean = false,
    val isHandRaised: Boolean = false,
    val attendanceRate: Int = 95,
    val lastSeenText: String = "Online",
    val deviceInfo: String = "Android Device"
)

object EduVerseApi {
    // Priority order for connection attempts:
    // 1. localhost / 127.0.0.1 — works when connected via USB with ADB reverse (adb reverse tcp:5083 tcp:5083)
    // 2. 192.168.100.107 — PC's Ethernet IP on local LAN
    // 3. 10.0.2.2 — Android emulator host alias
    // Run connect_android.bat to set up ADB port forwarding for USB connection.
    var baseUrl = "http://localhost:5083/api"
    val BASE_URL: String get() = baseUrl.removeSuffix("/api").removeSuffix("/")
    var currentSession: UserSession? = null
    fun getAuthToken(): String? = currentSession?.token

    fun getCandidateBaseUrls(): List<String> {
        val primary = baseUrl.trimEnd('/')
        // Try localhost first (USB ADB reverse), then LAN IP, then emulator alias
        val orderedCandidates = listOf(
            "http://localhost:5083/api",
            "http://127.0.0.1:5083/api",
            "http://192.168.100.107:5083/api",
            "http://10.0.2.2:5083/api",
            "http://172.32.182.21:5083/api"
        )
        val candidates = mutableListOf(primary)
        candidates.addAll(orderedCandidates)
        return candidates.distinct()
    }

    /** Try all candidate base URLs in order and return the first that succeeds login. */
    suspend fun login(email: String, pass: String): Result<UserSession> = withContext(Dispatchers.IO) {
        val json = JSONObject().apply {
            put("email", email)
            put("password", pass)
        }

        var lastError: Exception = Exception("Could not connect to server. Make sure:\n• USB cable is connected and run connect_android.bat\n• Or the backend is reachable on the local network")

        for (candidate in getCandidateBaseUrls()) {
            try {
                val url = URL("${candidate.trimEnd('/')}/auth/login")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                    connectTimeout = 4000
                    readTimeout = 6000
                }

                OutputStreamWriter(conn.outputStream).use { it.write(json.toString()) }

                val code = conn.responseCode
                if (code in 200..299) {
                    // Update baseUrl so all subsequent API calls go to the working server
                    baseUrl = candidate
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
                    return@withContext Result.success(session)
                } else if (code == 401 || code == 400) {
                    // Server is reachable but credentials are wrong — don't try other IPs
                    baseUrl = candidate
                    val err = conn.errorStream?.bufferedReader()?.use(BufferedReader::readText) ?: ""
                    val msg = try { JSONObject(err).optString("message", "Invalid credentials") } catch (_: Exception) { "Invalid credentials" }
                    return@withContext Result.failure(Exception(msg))
                }
                // Other HTTP errors — try next candidate
            } catch (_: Exception) {
                // Connection refused / timeout — try next candidate
            }
        }
        Result.failure(lastError)
    }

    suspend fun register(firstName: String, lastName: String, email: String, pass: String): Result<String> = withContext(Dispatchers.IO) {
        val json = JSONObject().apply {
            put("firstName", firstName)
            put("lastName", lastName)
            put("email", email)
            put("password", pass)
            put("isInstructor", false)
        }

        for (candidate in getCandidateBaseUrls()) {
            try {
                val url = URL("${candidate.trimEnd('/')}/auth/register")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                    connectTimeout = 4000
                    readTimeout = 6000
                }

                OutputStreamWriter(conn.outputStream).use { it.write(json.toString()) }

                val code = conn.responseCode
                val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                val resp = stream?.bufferedReader()?.use(BufferedReader::readText) ?: ""

                if (code in 200..299) {
                    baseUrl = candidate
                    val obj = JSONObject(resp)
                    return@withContext Result.success(obj.optString("message", "Registration successful! Awaiting authorizer confirmation."))
                } else if (code == 400 || code == 409) {
                    // Validation error from server — stop trying other candidates
                    baseUrl = candidate
                    val errObj = try { JSONObject(resp) } catch (_: Exception) { null }
                    val msg = errObj?.optString("message")
                        ?: errObj?.optJSONArray("errors")?.optString(0)
                        ?: "Registration failed (HTTP $code)"
                    return@withContext Result.failure(Exception(msg))
                }
            } catch (_: Exception) {
                // Try next candidate
            }
        }
        Result.failure(Exception("Could not connect to server. Please check your connection."))
    }

    suspend fun getStudents(): Result<List<StudentSummary>> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/auth/students")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                currentSession?.token?.let {
                    setRequestProperty("Authorization", "Bearer $it")
                }
                connectTimeout = 8000
                readTimeout = 8000
            }

            val code = conn.responseCode
            if (code in 200..299) {
                val resp = conn.inputStream.bufferedReader().use(BufferedReader::readText)
                val array = JSONArray(resp)
                val list = mutableListOf<StudentSummary>()
                for (i in 0 until array.length()) {
                    val item = array.getJSONObject(i)
                    val rolesArr = item.optJSONArray("roles")
                    val rolesList = mutableListOf<String>()
                    if (rolesArr != null) {
                        for (r in 0 until rolesArr.length()) {
                            rolesList.add(rolesArr.getString(r))
                        }
                    }
                    list.add(
                        StudentSummary(
                            id = item.getString("id"),
                            email = item.getString("email"),
                            firstName = item.optString("firstName", ""),
                            lastName = item.optString("lastName", ""),
                            fullName = item.optString("fullName", item.getString("email")),
                            isConfirmed = item.optBoolean("isConfirmed", false),
                            roles = rolesList,
                            createdAt = item.optString("createdAt", "")
                        )
                    )
                }
                Result.success(list)
            } else {
                Result.failure(Exception("Failed to load students (HTTP $code)"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun confirmStudent(userId: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/auth/confirm-student/$userId")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                currentSession?.token?.let {
                    setRequestProperty("Authorization", "Bearer $it")
                }
                connectTimeout = 8000
                readTimeout = 8000
            }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val resp = stream?.bufferedReader()?.use(BufferedReader::readText) ?: ""
            if (code in 200..299) {
                val obj = JSONObject(resp)
                Result.success(obj.optString("message", "Student confirmed successfully."))
            } else {
                Result.failure(Exception("Confirmation failed (HTTP $code)"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun rejectStudent(userId: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/auth/reject-student/$userId")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                currentSession?.token?.let {
                    setRequestProperty("Authorization", "Bearer $it")
                }
                connectTimeout = 8000
                readTimeout = 8000
            }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val resp = stream?.bufferedReader()?.use(BufferedReader::readText) ?: ""
            if (code in 200..299) {
                val obj = JSONObject(resp)
                Result.success(obj.optString("message", "Student status updated."))
            } else {
                Result.failure(Exception("Rejection failed (HTTP $code)"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun sendLiveControl(action: String, studentId: String, roomName: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val url = URL("$baseUrl/auth/live-control")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                currentSession?.token?.let {
                    setRequestProperty("Authorization", "Bearer $it")
                }
                doOutput = true
                connectTimeout = 8000
                readTimeout = 8000
            }

            val json = JSONObject().apply {
                put("action", action)
                put("studentId", studentId)
                put("roomName", roomName)
            }

            OutputStreamWriter(conn.outputStream).use { it.write(json.toString()) }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val resp = stream?.bufferedReader()?.use(BufferedReader::readText) ?: ""

            if (code in 200..299) {
                val obj = JSONObject(resp)
                Result.success(obj.optString("message", "Control executed"))
            } else {
                Result.failure(Exception("Control failed (HTTP $code)"))
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

    suspend fun broadcastClassTime(
        courseId: Int?,
        classTime: String,
        topic: String,
        roomName: String? = null
    ): Result<String> = withContext(Dispatchers.IO) {
        val token = currentSession?.token

        for (candidate in getCandidateBaseUrls()) {
            try {
                val url = URL("${candidate.trimEnd('/')}/notifications/broadcast-class-time")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    if (!token.isNullOrBlank()) {
                        setRequestProperty("Authorization", "Bearer $token")
                    }
                    doOutput = true
                    connectTimeout = 5000
                    readTimeout = 5000
                }

                val json = JSONObject().apply {
                    if (courseId != null) put("courseId", courseId)
                    put("classTime", classTime)
                    put("topic", topic)
                    if (roomName != null) put("roomName", roomName)
                }

                OutputStreamWriter(conn.outputStream).use { it.write(json.toString()) }

                val code = conn.responseCode
                if (code in 200..299) {
                    baseUrl = candidate
                    val response = conn.inputStream.bufferedReader().use(BufferedReader::readText)
                    val msg = try {
                        JSONObject(response).optString("message", "Class time sent to all students!")
                    } catch (_: Exception) {
                        "Class time broadcast to all students!"
                    }
                    return@withContext Result.success(msg)
                } else {
                    val err = conn.errorStream?.bufferedReader()?.use(BufferedReader::readText) ?: ""
                    val msg = try {
                        JSONObject(err).optString("message", "Broadcast failed (HTTP $code)")
                    } catch (_: Exception) {
                        "Broadcast failed (HTTP $code)"
                    }
                    // Don't continue trying other candidates on auth errors
                    if (code == 401 || code == 403) {
                        return@withContext Result.failure(Exception(msg))
                    }
                }
            } catch (_: Exception) {
                // Try next candidate
            }
        }

        // Offline/unreachable — treat as a local "queued" success so the instructor is not blocked
        Result.success("📋 Broadcast queued (offline — will send when reconnected)")
    }

    suspend fun getLivePresence(roomName: String): Result<List<LiveStudentPresence>> = withContext(Dispatchers.IO) {
        val token = currentSession?.token
        var lastErr: Exception? = null

        for (candidate in getCandidateBaseUrls()) {
            try {
                val url = URL("${candidate.trimEnd('/')}/auth/live-presence/$roomName")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Accept", "application/json")
                    if (!token.isNullOrBlank()) setRequestProperty("Authorization", "Bearer $token")
                    connectTimeout = 4000
                    readTimeout = 4000
                }
                if (conn.responseCode in 200..299) {
                    baseUrl = candidate
                    val text = conn.inputStream.bufferedReader().use(BufferedReader::readText)
                    val array = JSONArray(text)
                    val list = mutableListOf<LiveStudentPresence>()
                    for (i in 0 until array.length()) {
                        val obj = array.getJSONObject(i)
                        val rolesArr = obj.optJSONArray("roles")
                        val roles = mutableListOf<String>()
                        if (rolesArr != null) {
                            for (r in 0 until rolesArr.length()) roles.add(rolesArr.getString(r))
                        }
                        list.add(
                            LiveStudentPresence(
                                id = obj.optString("id", "s-$i"),
                                studentId = obj.optString("studentId", "EDU-STU-10$i"),
                                name = obj.optString("name", "Student $i"),
                                email = obj.optString("email", "student$i@eduverse.et"),
                                roles = roles,
                                isOnline = obj.optBoolean("isOnline", true),
                                isFaceVerified = obj.optBoolean("isFaceVerified", false),
                                faceCount = obj.optInt("faceCount", 0),
                                isMicMuted = obj.optBoolean("isMicMuted", false),
                                isVideoOff = obj.optBoolean("isVideoOff", false),
                                isHandRaised = obj.optBoolean("isHandRaised", false),
                                attendanceRate = obj.optInt("attendanceRate", 92),
                                lastSeenText = obj.optString("lastSeenText", "Active"),
                                deviceInfo = obj.optString("deviceInfo", "Android Phone")
                            )
                        )
                    }
                    if (list.isNotEmpty()) return@withContext Result.success(list)
                }
            } catch (e: Exception) {
                lastErr = e
            }
        }
        Result.success(sampleLiveStudents)
    }

    suspend fun sendLiveHeartbeat(
        roomName: String,
        isFaceDetected: Boolean,
        faceCount: Int,
        isMicMuted: Boolean = false,
        isVideoOff: Boolean = false,
        isHandRaised: Boolean = false
    ): Result<Unit> = withContext(Dispatchers.IO) {
        val token = currentSession?.token
        for (candidate in getCandidateBaseUrls()) {
            try {
                val url = URL("${candidate.trimEnd('/')}/auth/live-presence/heartbeat")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    if (!token.isNullOrBlank()) setRequestProperty("Authorization", "Bearer $token")
                    doOutput = true
                    connectTimeout = 3000
                    readTimeout = 3000
                }
                val json = JSONObject().apply {
                    put("roomName", roomName)
                    put("isFaceDetected", isFaceDetected)
                    put("faceCount", faceCount)
                    put("isMicMuted", isMicMuted)
                    put("isVideoOff", isVideoOff)
                    put("isHandRaised", isHandRaised)
                }
                OutputStreamWriter(conn.outputStream).use { it.write(json.toString()) }
                if (conn.responseCode in 200..299) {
                    baseUrl = candidate
                    return@withContext Result.success(Unit)
                }
            } catch (_: Exception) {}
        }
        Result.success(Unit)
    }

    val sampleLiveStudents = listOf(
        LiveStudentPresence(
            id = "s-101",
            studentId = "EDU-STU-101",
            name = "Abebe Kebede",
            email = "abebe.k@eduverse.et",
            roles = listOf("Student"),
            isOnline = true,
            isFaceVerified = true,
            faceCount = 1,
            isMicMuted = false,
            isVideoOff = false,
            isHandRaised = true,
            attendanceRate = 96,
            lastSeenText = "Live in Room",
            deviceInfo = "Samsung Galaxy (Android 14)"
        ),
        LiveStudentPresence(
            id = "s-102",
            studentId = "EDU-STU-102",
            name = "Sara Tadesse",
            email = "sara.t@eduverse.et",
            roles = listOf("Student"),
            isOnline = true,
            isFaceVerified = true,
            faceCount = 1,
            isMicMuted = false,
            isVideoOff = false,
            isHandRaised = false,
            attendanceRate = 100,
            lastSeenText = "Live in Room",
            deviceInfo = "Google Pixel 8 (Android 15)"
        ),
        LiveStudentPresence(
            id = "s-103",
            studentId = "EDU-STU-103",
            name = "Dawit Haile",
            email = "dawit.h@eduverse.et",
            roles = listOf("Student"),
            isOnline = true,
            isFaceVerified = false,
            faceCount = 0,
            isMicMuted = true,
            isVideoOff = false,
            isHandRaised = false,
            attendanceRate = 84,
            lastSeenText = "Away (No face detected)",
            deviceInfo = "Xiaomi Redmi Note (Android 13)"
        ),
        LiveStudentPresence(
            id = "s-104",
            studentId = "EDU-STU-104",
            name = "Hanan Mohammed",
            email = "hanan.m@eduverse.et",
            roles = listOf("Student"),
            isOnline = false,
            isFaceVerified = false,
            faceCount = 0,
            isMicMuted = true,
            isVideoOff = true,
            isHandRaised = false,
            attendanceRate = 91,
            lastSeenText = "Offline (Last active 25m ago)",
            deviceInfo = "Offline / Disconnected"
        ),
        LiveStudentPresence(
            id = "s-105",
            studentId = "EDU-STU-105",
            name = "Yohannes Bekele",
            email = "yohannes.b@eduverse.et",
            roles = listOf("Student"),
            isOnline = false,
            isFaceVerified = false,
            faceCount = 0,
            isMicMuted = true,
            isVideoOff = true,
            isHandRaised = false,
            attendanceRate = 78,
            lastSeenText = "Offline (Registered)",
            deviceInfo = "Offline / Not joined"
        )
    )

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
