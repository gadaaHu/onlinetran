package com.example.eduverse.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.eduverse.data.AdminUser
import com.example.eduverse.data.EduVerseApi
import kotlinx.coroutines.launch

enum class UserRoleFilter(val label: String) {
    ALL("All Users"),
    STUDENTS("Students"),
    INSTRUCTORS("Instructors"),
    ADMINS("Admins"),
    SUSPENDED("Suspended")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserManagementScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    var users by remember { mutableStateOf<List<AdminUser>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var actionMessage by remember { mutableStateOf<String?>(null) }
    var isError by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var selectedFilter by remember { mutableStateOf(UserRoleFilter.ALL) }

    // Dialog states
    var showCreateDialog by remember { mutableStateOf(false) }
    var userToDelete by remember { mutableStateOf<AdminUser?>(null) }
    var userForRoleChange by remember { mutableStateOf<AdminUser?>(null) }

    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    val bg = MaterialTheme.colorScheme.background
    val surface = MaterialTheme.colorScheme.surface
    val onSurface = MaterialTheme.colorScheme.onSurface
    val primary = MaterialTheme.colorScheme.primary

    fun showFeedback(msg: String, error: Boolean = false) {
        actionMessage = msg
        isError = error
        scope.launch {
            snackbarHostState.showSnackbar(msg)
        }
    }

    fun loadUsers(query: String? = null) {
        isLoading = true
        scope.launch {
            val res = EduVerseApi.getAdminUsers(query)
            isLoading = false
            res.onSuccess {
                users = it
            }.onFailure { err ->
                showFeedback(err.message ?: "Failed to load users", true)
            }
        }
    }

    LaunchedEffect(Unit) {
        loadUsers()
    }

    // Filtered users
    val filteredUsers = users.filter { u ->
        val matchesSearch = searchQuery.isBlank() ||
                u.fullName.contains(searchQuery, ignoreCase = true) ||
                u.email.contains(searchQuery, ignoreCase = true) ||
                u.roles.any { it.contains(searchQuery, ignoreCase = true) }

        val matchesFilter = when (selectedFilter) {
            UserRoleFilter.ALL -> true
            UserRoleFilter.STUDENTS -> u.roles.any { it.equals("Student", ignoreCase = true) }
            UserRoleFilter.INSTRUCTORS -> u.roles.any { it.equals("Instructor", ignoreCase = true) }
            UserRoleFilter.ADMINS -> u.roles.any { it.equals("Admin", ignoreCase = true) }
            UserRoleFilter.SUSPENDED -> !u.isActive
        }

        matchesSearch && matchesFilter
    }

    // Stats calculations
    val totalCount = users.size
    val activeCount = users.count { it.isActive }
    val instructorCount = users.count { it.roles.any { r -> r.equals("Instructor", ignoreCase = true) } }
    val adminCount = users.count { it.roles.any { r -> r.equals("Admin", ignoreCase = true) } }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = "👥 User Management",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            color = onSurface
                        )
                        Text(
                            text = "$totalCount registered accounts · Full Administration",
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
                    IconButton(onClick = { loadUsers(searchQuery.ifBlank { null }) }) {
                        Text("🔄", fontSize = 18.sp)
                    }
                    IconButton(onClick = { showCreateDialog = true }) {
                        Text("➕", fontSize = 18.sp)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = surface)
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showCreateDialog = true },
                containerColor = primary,
                contentColor = Color.White,
                shape = RoundedCornerShape(16.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("➕", fontSize = 16.sp)
                    Spacer(Modifier.width(6.dp))
                    Text("New User", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                }
            }
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
            // KPI Summary Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                AdminStatCard(title = "Total", value = "$totalCount", color = primary, modifier = Modifier.weight(1f))
                AdminStatCard(title = "Active", value = "$activeCount", color = Color(0xFF10B981), modifier = Modifier.weight(1f))
                AdminStatCard(title = "Instructors", value = "$instructorCount", color = Color(0xFF06B6D4), modifier = Modifier.weight(1f))
                AdminStatCard(title = "Admins", value = "$adminCount", color = Color(0xFFF59E0B), modifier = Modifier.weight(1f))
            }

            // Search input field
            OutlinedTextField(
                value = searchQuery,
                onValueChange = {
                    searchQuery = it
                },
                placeholder = { Text("Search by name, email, or role...", fontSize = 13.sp) },
                leadingIcon = { Text("🔍", fontSize = 14.sp) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Text("✖", fontSize = 12.sp, color = onSurface.copy(alpha = 0.5f))
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 10.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)
                )
            )

            // Role Filter Chips
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp)
            ) {
                items(UserRoleFilter.values()) { filter ->
                    val isSelected = selectedFilter == filter
                    val chipBg = if (isSelected) primary else surface
                    val chipText = if (isSelected) Color.White else onSurface.copy(alpha = 0.75f)

                    Surface(
                        shape = RoundedCornerShape(20.dp),
                        color = chipBg,
                        border = androidx.compose.foundation.BorderStroke(
                            1.dp,
                            if (isSelected) primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)
                        ),
                        modifier = Modifier.clickable { selectedFilter = filter }
                    ) {
                        Text(
                            text = filter.label,
                            color = chipText,
                            fontSize = 12.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 7.dp)
                        )
                    }
                }
            }

            // Users list
            if (isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = primary)
                }
            } else if (filteredUsers.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("🔍", fontSize = 42.sp)
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = if (searchQuery.isNotBlank()) "No users matching \"$searchQuery\"" else "No users in this filter",
                            fontSize = 14.sp,
                            color = onSurface.copy(alpha = 0.6f)
                        )
                    }
                }
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier
                        .fillMaxSize()
                        .weight(1f)
                ) {
                    items(filteredUsers, key = { it.id }) { user ->
                        AdminUserCard(
                            user = user,
                            onToggleStatus = {
                                scope.launch {
                                    val res = EduVerseApi.toggleAdminUserStatus(user.id)
                                    res.onSuccess { newStatus ->
                                        users = users.map { if (it.id == user.id) it.copy(isActive = newStatus) else it }
                                        showFeedback("Account ${if (newStatus) "activated" else "locked"}: ${user.email}")
                                    }.onFailure { err ->
                                        showFeedback(err.message ?: "Failed to update status", true)
                                    }
                                }
                            },
                            onChangeRole = { userForRoleChange = user },
                            onDelete = { userToDelete = user }
                        )
                    }
                }
            }
        }
    }

    // Role Selection Dialog
    userForRoleChange?.let { user ->
        RoleSelectionDialog(
            user = user,
            onDismiss = { userForRoleChange = null },
            onRoleSelected = { newRole ->
                userForRoleChange = null
                scope.launch {
                    val res = EduVerseApi.setAdminUserRole(user.id, newRole)
                    res.onSuccess {
                        users = users.map { if (it.id == user.id) it.copy(roles = listOf(newRole)) else it }
                        showFeedback("Assigned $newRole role to ${user.email}")
                    }.onFailure { err ->
                        showFeedback(err.message ?: "Role update failed", true)
                    }
                }
            }
        )
    }

    // Delete Confirmation Dialog
    userToDelete?.let { user ->
        AlertDialog(
            onDismissRequest = { userToDelete = null },
            title = { Text("Delete Account?", fontWeight = FontWeight.Bold) },
            text = {
                Text(
                    "Are you sure you want to permanently delete the account for ${user.fullName} (${user.email})? This action cannot be undone."
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        userToDelete = null
                        scope.launch {
                            val res = EduVerseApi.deleteAdminUser(user.id)
                            res.onSuccess {
                                users = users.filter { it.id != user.id }
                                showFeedback("User deleted successfully")
                            }.onFailure { err ->
                                showFeedback(err.message ?: "Failed to delete user", true)
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Delete Account", color = Color.White)
                }
            },
            dismissButton = {
                TextButton(onClick = { userToDelete = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Create User Dialog
    if (showCreateDialog) {
        CreateUserDialog(
            onDismiss = { showCreateDialog = false },
            onCreate = { fName, lName, email, pass, role ->
                showCreateDialog = false
                scope.launch {
                    val res = EduVerseApi.createAdminUser(fName, lName, email, pass, role)
                    res.onSuccess {
                        showFeedback("Account created for $email!")
                        loadUsers()
                    }.onFailure { err ->
                        showFeedback(err.message ?: "Account creation failed", true)
                    }
                }
            }
        )
    }
}

@Composable
fun AdminStatCard(
    title: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(1.dp, color.copy(alpha = 0.35f)),
        modifier = modifier
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp, horizontal = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = value,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                text = title,
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                maxLines = 1
            )
        }
    }
}

@Composable
fun AdminUserCard(
    user: AdminUser,
    onToggleStatus: () -> Unit,
    onChangeRole: () -> Unit,
    onDelete: () -> Unit
) {
    val primaryRole = user.primaryRole
    val isLocked = !user.isActive

    val roleBg = when (primaryRole.lowercase()) {
        "admin" -> Color(0xFF7C3AED)
        "instructor" -> Color(0xFF0284C7)
        else -> Color(0xFF059669)
    }

    Card(
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (isLocked) Color(0xFFEF4444).copy(alpha = 0.4f) else MaterialTheme.colorScheme.outline.copy(alpha = 0.25f)
        ),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Gradient avatar
                val initials = if (user.firstName.isNotBlank() && user.lastName.isNotBlank()) {
                    "${user.firstName.first()}${user.lastName.first()}".uppercase()
                } else {
                    user.email.take(2).uppercase()
                }

                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(
                                listOf(
                                    roleBg,
                                    roleBg.copy(alpha = 0.65f)
                                )
                            )
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = initials,
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )
                }

                Spacer(Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = user.fullName.ifBlank { user.email.substringBefore("@") },
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Spacer(Modifier.width(6.dp))
                        // Active / Locked badge
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(if (user.isActive) Color(0xFF10B981) else Color(0xFFEF4444))
                        )
                    }

                    Text(
                        text = user.email,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.65f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                // Primary role badge
                Surface(
                    shape = RoundedCornerShape(12.dp),
                    color = roleBg.copy(alpha = 0.15f),
                    border = androidx.compose.foundation.BorderStroke(1.dp, roleBg.copy(alpha = 0.5f))
                ) {
                    Text(
                        text = primaryRole,
                        color = roleBg,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // Action row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Role button
                OutlinedButton(
                    onClick = onChangeRole,
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Text("🎭 Role", fontSize = 12.sp)
                }

                // Toggle status button
                OutlinedButton(
                    onClick = onToggleStatus,
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 6.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = if (user.isActive) Color(0xFFF59E0B) else Color(0xFF10B981)
                    ),
                    modifier = Modifier.weight(1f)
                ) {
                    Text(if (user.isActive) "🔒 Lock" else "🔓 Unlock", fontSize = 12.sp)
                }

                // Delete button
                IconButton(
                    onClick = onDelete,
                    modifier = Modifier.size(36.dp)
                ) {
                    Text("🗑️", fontSize = 16.sp)
                }
            }
        }
    }
}

@Composable
fun RoleSelectionDialog(
    user: AdminUser,
    onDismiss: () -> Unit,
    onRoleSelected: (String) -> Unit
) {
    val roles = listOf("Student", "Instructor", "Admin")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Change Role for ${user.fullName}", fontWeight = FontWeight.Bold, fontSize = 16.sp) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    "Select the new access level for ${user.email}:",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )
                Spacer(Modifier.height(4.dp))
                roles.forEach { role ->
                    val isCurrent = user.roles.any { it.equals(role, ignoreCase = true) }
                    Surface(
                        shape = RoundedCornerShape(10.dp),
                        color = if (isCurrent) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surface,
                        border = androidx.compose.foundation.BorderStroke(
                            1.dp,
                            if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)
                        ),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onRoleSelected(role) }
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val icon = when (role) {
                                "Admin" -> "👑"
                                "Instructor" -> "🎓"
                                else -> "📚"
                            }
                            Text(icon, fontSize = 16.sp)
                            Spacer(Modifier.width(10.dp))
                            Text(
                                text = role,
                                fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Medium,
                                color = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.weight(1f)
                            )
                            if (isCurrent) {
                                Text("✓ Current", fontSize = 11.sp, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateUserDialog(
    onDismiss: () -> Unit,
    onCreate: (firstName: String, lastName: String, email: String, pass: String, role: String) -> Unit
) {
    var firstName by remember { mutableStateOf("") }
    var lastName by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var selectedRole by remember { mutableStateOf("Student") }
    var roleDropdownExpanded by remember { mutableStateOf(false) }

    val roles = listOf("Student", "Instructor", "Admin")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create New User", fontWeight = FontWeight.Bold) },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                OutlinedTextField(
                    value = firstName,
                    onValueChange = { firstName = it },
                    label = { Text("First Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = lastName,
                    onValueChange = { lastName = it },
                    label = { Text("Last Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email Address") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password (min 6 characters)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(4.dp))
                Text("Role Assignment:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    roles.forEach { role ->
                        val isSelected = selectedRole == role
                        Surface(
                            shape = RoundedCornerShape(8.dp),
                            color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
                            border = androidx.compose.foundation.BorderStroke(
                                1.dp,
                                if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.4f)
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .clickable { selectedRole = role }
                        ) {
                            Box(
                                modifier = Modifier.padding(vertical = 8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = role,
                                    fontSize = 11.sp,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (email.isNotBlank() && password.isNotBlank()) {
                        onCreate(firstName.trim(), lastName.trim(), email.trim(), password, selectedRole)
                    }
                },
                enabled = email.isNotBlank() && password.length >= 6
            ) {
                Text("Create User")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
