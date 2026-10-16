package com.example.eduverse

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data object LoginRoute : NavKey

@Serializable
data object RegisterRoute : NavKey

@Serializable
data object CoursesRoute : NavKey

@Serializable
data object AuthorizerRoute : NavKey

@Serializable
data object UserManagementRoute : NavKey

@Serializable
data object NotificationsRoute : NavKey

@Serializable
data object ProgressRoute : NavKey

@Serializable
data class ClassroomRoute(val roomName: String, val lessonTitle: String) : NavKey
