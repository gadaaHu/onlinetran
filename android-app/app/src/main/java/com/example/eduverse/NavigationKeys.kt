package com.example.eduverse

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data object LoginRoute : NavKey

@Serializable
data object CoursesRoute : NavKey

@Serializable
data class ClassroomRoute(val roomName: String, val lessonTitle: String) : NavKey
