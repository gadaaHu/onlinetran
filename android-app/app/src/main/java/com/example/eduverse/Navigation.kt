package com.example.eduverse

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack
import androidx.navigation3.ui.NavDisplay
import com.example.eduverse.data.EduVerseApi
import com.example.eduverse.ui.auth.LoginScreen
import com.example.eduverse.ui.classroom.AndroidLiveClassroomScreen
import com.example.eduverse.ui.courses.CourseListScreen

@Composable
fun MainNavigation() {
    val initialRoute = if (EduVerseApi.currentSession != null) CoursesRoute else LoginRoute
    val backStack = rememberNavBackStack(initialRoute)

    NavDisplay(
        backStack = backStack,
        onBack = {
            if (backStack.size > 1) {
                backStack.removeLastOrNull()
            }
        },
        entryProvider = entryProvider {
            entry<LoginRoute> {
                LoginScreen(
                    onLoginSuccess = {
                        backStack.clear()
                        backStack.add(CoursesRoute)
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }

            entry<CoursesRoute> {
                CourseListScreen(
                    onOpenClassroom = { roomName, lessonTitle ->
                        backStack.add(ClassroomRoute(roomName, lessonTitle))
                    },
                    onLogout = {
                        EduVerseApi.currentSession = null
                        backStack.clear()
                        backStack.add(LoginRoute)
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }

            entry<ClassroomRoute> { route ->
                AndroidLiveClassroomScreen(
                    roomName = route.roomName,
                    lessonTitle = route.lessonTitle,
                    onLeaveClass = {
                        backStack.removeLastOrNull()
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    )
}
