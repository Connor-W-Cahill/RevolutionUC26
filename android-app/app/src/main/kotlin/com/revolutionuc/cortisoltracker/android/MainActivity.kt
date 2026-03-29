package com.revolutionuc.cortisoltracker.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Today
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.FirebaseApp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FirebaseApp.initializeApp(this)
        val graph = AppGraph()
        setContent {
            CortisolTrackerTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    val factory = remember(graph) { AppViewModelFactory(graph) }
                    val sessionViewModel: SessionViewModel = viewModel(factory = factory)
                    CortisolTrackerAndroidApp(sessionViewModel, factory)
                }
            }
        }
    }
}

class AppViewModelFactory(
    private val appGraph: AppGraph
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        val repository = appGraph.repository
        val model = when {
            modelClass.isAssignableFrom(SessionViewModel::class.java) -> SessionViewModel(repository)
            modelClass.isAssignableFrom(DashboardViewModel::class.java) -> DashboardViewModel(repository)
            modelClass.isAssignableFrom(CalendarViewModel::class.java) -> CalendarViewModel(repository)
            modelClass.isAssignableFrom(FriendsViewModel::class.java) -> FriendsViewModel(repository)
            modelClass.isAssignableFrom(TipsViewModel::class.java) -> TipsViewModel(repository)
            modelClass.isAssignableFrom(GroupsViewModel::class.java) -> GroupsViewModel(repository)
            else -> error("Unknown ViewModel: ${modelClass.name}")
        }
        @Suppress("UNCHECKED_CAST")
        return model as T
    }
}

data class SessionUiState(
    val isAuthenticated: Boolean = false,
    val isLoading: Boolean = true,
    val user: AppUser? = null,
    val error: String? = null
)

class SessionViewModel(
    private val repository: CortisolRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(SessionUiState())
    val uiState: StateFlow<SessionUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.authState().collect { uid ->
                if (uid == null) {
                    _uiState.value = SessionUiState(isAuthenticated = false, isLoading = false)
                } else {
                    val user = repository.fetchUser(uid)
                    _uiState.value = SessionUiState(
                        isAuthenticated = true,
                        isLoading = false,
                        user = user
                    )
                    repository.seedBackgroundRefresh()
                }
            }
        }
    }

    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching { repository.signIn(email, password) }
                .onSuccess { user ->
                    _uiState.value = SessionUiState(isAuthenticated = true, isLoading = false, user = user)
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(isLoading = false, error = error.message)
                }
        }
    }

    fun signUp(displayName: String, email: String, password: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching { repository.signUp(email, password, displayName) }
                .onSuccess { user ->
                    _uiState.value = SessionUiState(isAuthenticated = true, isLoading = false, user = user)
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(isLoading = false, error = error.message)
                }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            repository.signOut()
            _uiState.value = SessionUiState(isAuthenticated = false, isLoading = false)
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}

data class DashboardUiState(
    val latestReading: CortisolReading? = null,
    val todayReadings: List<CortisolReading> = emptyList(),
    val streak: Streak? = null,
    val latestSpike: SpikeEvent? = null,
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null
) {
    val averageStressToday: Double?
        get() = if (todayReadings.isEmpty()) null else todayReadings.map { it.stressLevel }.average()
}

class DashboardViewModel(
    private val repository: CortisolRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState = _uiState.asStateFlow()

    fun load() {
        val userId = repository.currentUserId ?: return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching {
                val readings = repository.fetchReadingsForDate(userId, Date())
                val spikes = repository.fetchSpikeEvents(userId)
                val streak = repository.fetchStreak(userId)
                Triple(readings, spikes.firstOrNull(), streak)
            }.onSuccess { (readings, spike, streak) ->
                _uiState.value = DashboardUiState(
                    latestReading = readings.firstOrNull(),
                    todayReadings = readings,
                    latestSpike = spike?.takeIf { it.timestamp.time > System.currentTimeMillis() - 7_200_000L },
                    streak = streak
                )
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(isLoading = false, error = error.message)
            }
        }
    }

    fun saveReading(reading: CortisolReading) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true, error = null)
            runCatching { repository.saveReading(reading) }
                .onSuccess {
                    val updated = listOf(reading) + _uiState.value.todayReadings
                    _uiState.value = _uiState.value.copy(
                        latestReading = reading,
                        todayReadings = updated,
                        isSaving = false
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(isSaving = false, error = error.message)
                }
        }
    }

    fun captureReading(onResult: (CortisolReading) -> Unit) {
        val userId = repository.currentUserId ?: return
        viewModelScope.launch {
            runCatching { repository.captureMeasurement(userId) }
                .onSuccess(onResult)
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(error = error.message)
                }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}

data class CalendarUiState(
    val selectedDate: Date = Date(),
    val readings: List<CortisolReading> = emptyList(),
    val activities: List<ActivityEntry> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
) {
    val averageStress: Double?
        get() = if (readings.isEmpty()) null else readings.map { it.stressLevel }.average()
}

class CalendarViewModel(
    private val repository: CortisolRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(CalendarUiState())
    val uiState = _uiState.asStateFlow()

    fun load(date: Date = _uiState.value.selectedDate) {
        val userId = repository.currentUserId ?: return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(selectedDate = date, isLoading = true, error = null)
            runCatching {
                repository.fetchReadingsForDate(userId, date) to repository.fetchActivitiesForDate(userId, date)
            }.onSuccess { (readings, activities) ->
                _uiState.value = CalendarUiState(
                    selectedDate = date,
                    readings = readings,
                    activities = activities
                )
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(isLoading = false, error = error.message)
            }
        }
    }

    fun addActivity(category: ActivityCategory, title: String, notes: String?, rating: Int?) {
        val userId = repository.currentUserId ?: return
        val date = _uiState.value.selectedDate
        viewModelScope.launch {
            val activity = ActivityEntry(
                userId = userId,
                date = date,
                category = category,
                title = title,
                notes = notes?.takeIf { it.isNotBlank() },
                rating = rating
            )
            runCatching { repository.saveActivity(activity) }
                .onSuccess {
                    _uiState.value = _uiState.value.copy(
                        activities = listOf(activity) + _uiState.value.activities
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(error = error.message)
                }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}

data class FriendsUiState(
    val friends: List<Friend> = emptyList(),
    val searchResults: List<Friend> = emptyList(),
    val incomingRequests: List<Map<String, Any?>> = emptyList(),
    val outgoingRequests: List<Map<String, Any?>> = emptyList(),
    val shares: Map<String, ShareRecord> = emptyMap(),
    val isLoading: Boolean = false,
    val isSearching: Boolean = false,
    val error: String? = null
)

class FriendsViewModel(
    private val repository: CortisolRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(FriendsUiState())
    val uiState = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching {
                val friends = repository.fetchFriends()
                val shares = repository.fetchOutgoingShares()
                val requests = repository.getFriendRequests()
                Triple(friends, shares, requests)
            }.onSuccess { (friends, shares, requests) ->
                _uiState.value = FriendsUiState(
                    friends = friends,
                    shares = shares,
                    incomingRequests = requests.first,
                    outgoingRequests = requests.second
                )
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(isLoading = false, error = error.message)
            }
        }
    }

    fun search(query: String) {
        viewModelScope.launch {
            if (query.isBlank()) {
                _uiState.value = _uiState.value.copy(searchResults = emptyList())
                return@launch
            }
            _uiState.value = _uiState.value.copy(isSearching = true)
            runCatching { repository.searchUsers(query) }
                .onSuccess { users ->
                    val friendIds = _uiState.value.friends.map { it.id }.toSet()
                    _uiState.value = _uiState.value.copy(
                        isSearching = false,
                        searchResults = users.filterNot { it.id in friendIds }
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(isSearching = false, error = error.message)
                }
        }
    }

    fun sendFriendRequest(targetUserId: String) {
        viewModelScope.launch {
            runCatching { repository.sendFriendRequest(targetUserId) }
                .onSuccess {
                    _uiState.value = _uiState.value.copy(
                        searchResults = _uiState.value.searchResults.filterNot { it.id == targetUserId }
                    )
                    load()
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(error = error.message)
                }
        }
    }

    fun updateShare(friendId: String, permissions: SharePermissions) {
        viewModelScope.launch {
            runCatching { repository.setShare(friendId, permissions) }
                .onSuccess {
                    load()
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(error = error.message)
                }
        }
    }

    fun revokeShare(friendId: String) {
        viewModelScope.launch {
            runCatching { repository.revokeShare(friendId) }
                .onSuccess { load() }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(error = error.message)
                }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}

data class TipsUiState(
    val tips: List<Tip> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class TipsViewModel(
    private val repository: CortisolRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(TipsUiState())
    val uiState = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching { repository.fetchTips() }
                .onSuccess { tips ->
                    _uiState.value = TipsUiState(tips = tips, isLoading = false)
                }
                .onFailure { error ->
                    _uiState.value = TipsUiState(isLoading = false, error = error.message)
                }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }
}

data class GroupsUiState(
    val groups: List<StressGroup> = emptyList(),
    val stats: Map<String, GroupDailyStat> = emptyMap(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class GroupsViewModel(
    private val repository: CortisolRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow(GroupsUiState())
    val uiState = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching {
                val groups = repository.fetchGroups()
                val stats = groups.associate { group ->
                    group.id to repository.fetchGroupDailyStats(group.id).firstOrNull()
                }.filterValues { it != null }.mapValues { it.value!! }
                groups to stats
            }.onSuccess { (groups, stats) ->
                _uiState.value = GroupsUiState(groups = groups, stats = stats)
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(isLoading = false, error = error.message)
            }
        }
    }

    fun createGroup(name: String) {
        viewModelScope.launch {
            runCatching { repository.createGroup(name) }
                .onSuccess { load() }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(error = error.message)
                }
        }
    }

    fun addMember(group: StressGroup, memberId: String) {
        viewModelScope.launch {
            runCatching { repository.addGroupMember(group, memberId) }
                .onSuccess { load() }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(error = error.message)
                }
        }
    }
}

@Composable
fun CortisolTrackerAndroidApp(
    sessionViewModel: SessionViewModel,
    factory: AppViewModelFactory
) {
    val sessionState by sessionViewModel.uiState.collectAsStateWithLifecycle()
    if (sessionState.isLoading) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        return
    }

    sessionState.error?.let { message ->
        AlertDialog(
            onDismissRequest = sessionViewModel::clearError,
            confirmButton = { TextButton(onClick = sessionViewModel::clearError) { Text("OK") } },
            title = { Text("Error") },
            text = { Text(message) }
        )
    }

    if (!sessionState.isAuthenticated) {
        AuthScreen(sessionState, sessionViewModel)
    } else {
        val dashboardViewModel: DashboardViewModel = viewModel(factory = factory)
        val calendarViewModel: CalendarViewModel = viewModel(factory = factory)
        val friendsViewModel: FriendsViewModel = viewModel(factory = factory)
        val tipsViewModel: TipsViewModel = viewModel(factory = factory)
        val groupsViewModel: GroupsViewModel = viewModel(factory = factory)
        MainShell(
            user = sessionState.user,
            onSignOut = sessionViewModel::signOut,
            dashboardViewModel = dashboardViewModel,
            calendarViewModel = calendarViewModel,
            friendsViewModel = friendsViewModel,
            tipsViewModel = tipsViewModel,
            groupsViewModel = groupsViewModel
        )
    }
}

@Composable
private fun AuthScreen(
    sessionState: SessionUiState,
    sessionViewModel: SessionViewModel
) {
    var showSignUp by rememberSaveable { mutableStateOf(false) }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Cortisol Tracker", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text("Track your stress, improve your life", color = TextSecondary)
        Spacer(Modifier.height(32.dp))
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = { sessionViewModel.signIn(email, password) },
            enabled = email.isNotBlank() && password.isNotBlank() && !sessionState.isLoading,
            modifier = Modifier.fillMaxWidth()
        ) {
            if (sessionState.isLoading) CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
            else Text("Sign In")
        }
        Spacer(Modifier.height(12.dp))
        Text("Apple Sign In remains iOS-specific. Android uses email/password for now.", color = TextSecondary, textAlign = TextAlign.Center)
        Spacer(Modifier.height(12.dp))
        TextButton(onClick = { showSignUp = true }) {
            Text("Don't have an account? Sign Up")
        }
    }

    if (showSignUp) {
        SignUpDialog(
            isLoading = sessionState.isLoading,
            onDismiss = { showSignUp = false },
            onCreate = { displayName, signUpEmail, signUpPassword ->
                sessionViewModel.signUp(displayName, signUpEmail, signUpPassword)
                showSignUp = false
            }
        )
    }
}

@Composable
private fun SignUpDialog(
    isLoading: Boolean,
    onDismiss: () -> Unit,
    onCreate: (String, String, String) -> Unit
) {
    var displayName by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var confirmPassword by rememberSaveable { mutableStateOf("") }
    val valid = displayName.isNotBlank() && email.isNotBlank() && password.length >= 6 && password == confirmPassword
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = { onCreate(displayName, email, password) }, enabled = valid && !isLoading) {
                Text("Create Account")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        title = { Text("Create Account") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = displayName, onValueChange = { displayName = it }, label = { Text("Display Name") })
                OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Email") })
                OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Password") })
                OutlinedTextField(value = confirmPassword, onValueChange = { confirmPassword = it }, label = { Text("Confirm Password") })
                if (confirmPassword.isNotBlank() && password != confirmPassword) {
                    Text("Passwords don't match", color = MaterialTheme.colorScheme.error)
                }
            }
        }
    )
}

private enum class MainTab(val title: String) {
    DASHBOARD("Dashboard"),
    CALENDAR("Calendar"),
    FRIENDS("Friends"),
    TIPS("Tips")
}

@Composable
private fun MainShell(
    user: AppUser?,
    onSignOut: () -> Unit,
    dashboardViewModel: DashboardViewModel,
    calendarViewModel: CalendarViewModel,
    friendsViewModel: FriendsViewModel,
    tipsViewModel: TipsViewModel,
    groupsViewModel: GroupsViewModel
) {
    var selectedTab by rememberSaveable { mutableStateOf(MainTab.DASHBOARD) }
    var showGroups by rememberSaveable { mutableStateOf(false) }
    Scaffold(
        bottomBar = {
            TabRow(selectedTabIndex = MainTab.entries.indexOf(selectedTab)) {
                MainTab.entries.forEach { tab ->
                    Tab(
                        selected = tab == selectedTab,
                        onClick = { selectedTab = tab },
                        text = { Text(tab.title) },
                        icon = {
                            Icon(
                                imageVector = when (tab) {
                                    MainTab.DASHBOARD -> Icons.Default.Favorite
                                    MainTab.CALENDAR -> Icons.Default.CalendarToday
                                    MainTab.FRIENDS -> Icons.Default.Groups
                                    MainTab.TIPS -> Icons.Default.Lightbulb
                                },
                                contentDescription = tab.title
                            )
                        }
                    )
                }
            }
        }
    ) { padding ->
        Box(modifier = Modifier.padding(padding)) {
            when (selectedTab) {
                MainTab.DASHBOARD -> DashboardScreen(user, onSignOut, dashboardViewModel)
                MainTab.CALENDAR -> CalendarScreen(calendarViewModel)
                MainTab.FRIENDS -> FriendsScreen(friendsViewModel, onOpenGroups = { showGroups = true })
                MainTab.TIPS -> TipsScreen(tipsViewModel)
            }
        }
    }

    if (showGroups) {
        GroupsDialog(groupsViewModel = groupsViewModel, onDismiss = { showGroups = false })
    }
}

@Composable
private fun DashboardScreen(
    user: AppUser?,
    onSignOut: () -> Unit,
    viewModel: DashboardViewModel
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showScan by rememberSaveable { mutableStateOf(false) }
    var capturedReading by remember { mutableStateOf<CortisolReading?>(null) }
    LaunchedEffect(Unit) { viewModel.load() }

    uiState.error?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::clearError,
            confirmButton = { TextButton(onClick = viewModel::clearError) { Text("OK") } },
            title = { Text("Error") },
            text = { Text(message) }
        )
    }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(greetingText(), color = TextSecondary)
                    Text(user?.displayName ?: "there", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                }
                TextButton(onClick = onSignOut) { Text("Sign Out", color = DeepTeal) }
            }
        }
        item {
            Card(colors = CardDefaults.cardColors(containerColor = CardBackground)) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("Current Stress", color = TextSecondary)
                    Spacer(Modifier.height(8.dp))
                    StressGauge(reading = uiState.latestReading)
                }
            }
        }
        uiState.latestReading?.let { reading ->
            item { VitalsRow(reading) }
        }
        item {
            Button(onClick = {
                showScan = true
                capturedReading = null
                viewModel.captureReading { capturedReading = it }
            }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Default.CameraAlt, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Take Reading")
            }
        }
        if (uiState.todayReadings.isNotEmpty()) {
            item {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("Today's Readings", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    uiState.averageStressToday?.let { Text("Avg: ${it.toInt()}", color = TextSecondary) }
                }
            }
            items(uiState.todayReadings) { reading ->
                Card {
                    Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(reading.stressCategory.brandColor)
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Stress: ${reading.stressLevel.toInt()}", fontWeight = FontWeight.Medium)
                            Text(formatTime(reading.timestamp), color = TextSecondary)
                        }
                        Text("${reading.pulseRate.toInt()} bpm", color = TextSecondary)
                    }
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    MiniInfoCard("Streak", uiState.streak?.currentReadingStreak?.let { "$it days" } ?: "0 days", Modifier.weight(1f))
                    MiniInfoCard(
                        "Latest Spike",
                        uiState.latestSpike?.severity?.replaceFirstChar(Char::titlecase) ?: "None in 2h",
                        Modifier.weight(1f)
                    )
                }
            }
        }
    }

    if (showScan) {
        ScanDialog(
            capturedReading = capturedReading,
            isSaving = uiState.isSaving,
            onDismiss = { showScan = false },
            onRetry = { viewModel.captureReading { capturedReading = it } },
            onSave = {
                capturedReading?.let(viewModel::saveReading)
                showScan = false
            }
        )
    }
}

@Composable
private fun StressGauge(reading: CortisolReading?) {
    if (reading == null) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.Today, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(64.dp))
            Spacer(Modifier.height(8.dp))
            Text("No readings yet", fontWeight = FontWeight.SemiBold)
            Text("Tap scan to measure your vitals", color = TextSecondary)
        }
        return
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(132.dp)
                .clip(CircleShape)
                .background(reading.stressCategory.brandColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Text("${reading.stressLevel.toInt()}", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(12.dp))
        Text(reading.stressCategory.label, color = reading.stressCategory.brandColor, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun VitalsRow(reading: CortisolReading) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
        VitalCard("Pulse", "${reading.pulseRate.toInt()}", "BPM", WarmCoral, Modifier.weight(1f))
        VitalCard("Breathing", "${reading.breathingRate.toInt()}", "br/min", CalmBlue, Modifier.weight(1f))
        reading.bloodPressureSystolic?.let {
            VitalCard("Blood Pressure", "${it.toInt()}", "mmHg", SoftPurple, Modifier.weight(1f))
        }
    }
}

@Composable
private fun VitalCard(label: String, value: String, unit: String, tint: Color, modifier: Modifier = Modifier) {
    Card(modifier = modifier, colors = CardDefaults.cardColors(containerColor = tint.copy(alpha = 0.08f))) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(label, color = TextSecondary)
            Text(value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Text(unit, color = TextSecondary)
        }
    }
}

@Composable
private fun MiniInfoCard(label: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(label, color = TextSecondary)
            Spacer(Modifier.height(6.dp))
            Text(value, fontWeight = FontWeight.SemiBold)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScanDialog(
    capturedReading: CortisolReading?,
    isSaving: Boolean,
    onDismiss: () -> Unit,
    onRetry: () -> Unit,
    onSave: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        text = {
            Column {
                if (capturedReading == null) {
                    Text("Get ready to scan", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Text("This Android port currently uses a secure demo measurement provider until the Android Presage SDK is wired in.")
                    Spacer(Modifier.height(16.dp))
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(220.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .background(DividerColor.copy(alpha = 0.4f)),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                } else {
                    Text("Your Results", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(12.dp))
                    StressGauge(capturedReading)
                    Spacer(Modifier.height(12.dp))
                    VitalsRow(capturedReading)
                }
            }
        },
        dismissButton = {
            if (capturedReading == null) {
                TextButton(onClick = onDismiss) { Text("Cancel") }
            } else {
                TextButton(onClick = onDismiss) { Text("Discard") }
            }
        },
        confirmButton = {
            if (capturedReading != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = onRetry) { Text("Scan Again") }
                    Button(onClick = onSave, enabled = !isSaving) { Text("Save Reading") }
                }
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CalendarScreen(viewModel: CalendarViewModel) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showAddActivity by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.load() }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Calendar") },
            actions = {
                IconButton(onClick = { showAddActivity = true }) {
                    Icon(Icons.Default.Add, contentDescription = "Add Activity")
                }
            }
        )
        LazyColumn(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item {
                Card {
                    Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                        Text("Selected Date", color = TextSecondary)
                        Text(formatDate(uiState.selectedDate), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
            uiState.averageStress?.let { avg ->
                item {
                    Card {
                        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Daily Average", color = TextSecondary)
                                Text("Stress: ${avg.toInt()}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                            }
                            Text("${uiState.readings.size} readings", color = TextSecondary)
                        }
                    }
                }
            }
            if (uiState.readings.isNotEmpty()) {
                item { Text("Readings", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold) }
                items(uiState.readings) { reading ->
                    Card {
                        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(reading.stressCategory.emoji)
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Stress: ${reading.stressLevel.toInt()}", fontWeight = FontWeight.Medium)
                                Text(formatTime(reading.timestamp), color = TextSecondary)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("${reading.pulseRate.toInt()} bpm")
                                Text("${reading.breathingRate.toInt()} br/min", color = TextSecondary)
                            }
                        }
                    }
                }
            }
            item { Text("Activities", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold) }
            if (uiState.activities.isEmpty()) {
                item {
                    Card {
                        Text("No activities logged", modifier = Modifier.fillMaxWidth().padding(24.dp), textAlign = TextAlign.Center, color = TextSecondary)
                    }
                }
            } else {
                items(uiState.activities) { activity ->
                    Card {
                        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(activity.category.wireValue)
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(activity.title, fontWeight = FontWeight.Medium)
                                activity.notes?.let { Text(it, color = TextSecondary) }
                            }
                            Text(activity.rating?.let { "$it/5" } ?: "", color = TextSecondary)
                        }
                    }
                }
            }
        }
    }

    if (showAddActivity) {
        AddActivityDialog(
            onDismiss = { showAddActivity = false },
            onSave = { category, title, notes, rating ->
                viewModel.addActivity(category, title, notes, rating)
                showAddActivity = false
            }
        )
    }
}

@Composable
private fun AddActivityDialog(
    onDismiss: () -> Unit,
    onSave: (ActivityCategory, String, String?, Int?) -> Unit
) {
    var title by rememberSaveable { mutableStateOf("") }
    var notes by rememberSaveable { mutableStateOf("") }
    var rating by rememberSaveable { mutableStateOf("3") }
    var category by rememberSaveable { mutableStateOf(ActivityCategory.SLEEP) }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                onSave(category, title, notes, rating.toIntOrNull())
            }, enabled = title.isNotBlank()) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        title = { Text("Log Activity") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Category", color = TextSecondary)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.verticalScroll(rememberScrollState())) {
                    ActivityCategory.entries.forEach {
                        FilterChip(selected = category == it, onClick = { category = it }, label = { Text(it.wireValue) })
                    }
                }
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("Title") })
                OutlinedTextField(value = notes, onValueChange = { notes = it }, label = { Text("Notes") })
                OutlinedTextField(value = rating, onValueChange = { rating = it.filter(Char::isDigit) }, label = { Text("Rating (1-5)") })
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FriendsScreen(viewModel: FriendsViewModel, onOpenGroups: () -> Unit) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showSearch by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.load() }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Friends") },
            actions = {
                IconButton(onClick = onOpenGroups) { Icon(Icons.Default.Groups, contentDescription = "Groups") }
                IconButton(onClick = { showSearch = true }) { Icon(Icons.Default.PersonAdd, contentDescription = "Add Friend") }
            }
        )
        if (uiState.friends.isEmpty() && !uiState.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No Friends Yet", color = TextSecondary)
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (uiState.incomingRequests.isNotEmpty() || uiState.outgoingRequests.isNotEmpty()) {
                    item {
                        Card {
                            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text("Friend Requests", fontWeight = FontWeight.SemiBold)
                                uiState.incomingRequests.forEach {
                                    Text("Incoming from ${it["fromUserID"] ?: "unknown"}", color = TextSecondary)
                                }
                                uiState.outgoingRequests.forEach {
                                    Text("Outgoing to ${it["toUserID"] ?: "unknown"}", color = TextSecondary)
                                }
                            }
                        }
                    }
                }
                items(uiState.friends) { friend ->
                    FriendCard(friend, uiState.shares[friend.id], onEnableShare = {
                        viewModel.updateShare(friend.id, SharePermissions())
                    }, onRevokeShare = {
                        viewModel.revokeShare(friend.id)
                    })
                }
            }
        }
    }

    if (showSearch) {
        SearchFriendsDialog(
            uiState = uiState,
            onDismiss = { showSearch = false },
            onQueryChange = viewModel::search,
            onAdd = viewModel::sendFriendRequest
        )
    }
}

@Composable
private fun FriendCard(
    friend: Friend,
    shareRecord: ShareRecord?,
    onEnableShare: () -> Unit,
    onRevokeShare: () -> Unit
) {
    Card {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(Mint),
                    contentAlignment = Alignment.Center
                ) {
                    Text(friend.displayName.take(1).uppercase(), fontWeight = FontWeight.Bold, color = DeepTeal)
                }
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(friend.displayName, fontWeight = FontWeight.SemiBold)
                    Text(friend.latestReadingTime?.let { relativeTime(it) } ?: "No data", color = TextSecondary)
                }
                friend.stressCategory?.let {
                    Text("${it.emoji} ${it.label}", color = TextSecondary)
                }
            }
            Divider()
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (shareRecord == null) {
                    FilledTonalButton(onClick = onEnableShare) { Text("Enable Share") }
                } else {
                    OutlinedButton(onClick = onRevokeShare) { Text("Revoke Share") }
                }
            }
        }
    }
}

@Composable
private fun SearchFriendsDialog(
    uiState: FriendsUiState,
    onDismiss: () -> Unit,
    onQueryChange: (String) -> Unit,
    onAdd: (String) -> Unit
) {
    var query by rememberSaveable { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } },
        title = { Text("Add Friend") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = query, onValueChange = {
                    query = it
                    onQueryChange(it)
                }, label = { Text("Search by name") })
                if (uiState.isSearching) {
                    CircularProgressIndicator()
                } else if (uiState.searchResults.isEmpty() && query.isNotBlank()) {
                    Text("No results", color = TextSecondary)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        uiState.searchResults.forEach { user ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(user.displayName, modifier = Modifier.weight(1f))
                                TextButton(onClick = { onAdd(user.id) }) { Text("Add") }
                            }
                        }
                    }
                }
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TipsScreen(viewModel: TipsViewModel) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val expandedIds = remember { mutableStateListOf<String>() }
    LaunchedEffect(Unit) { viewModel.load() }
    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Tips") })
        when {
            uiState.isLoading -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            uiState.tips.isEmpty() -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("No Tips Yet", color = TextSecondary) }
            else -> LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items(uiState.tips) { tip ->
                    val expanded = tip.id in expandedIds
                    Card(
                        modifier = Modifier.clickable {
                            if (expanded) expandedIds.remove(tip.id) else expandedIds.add(tip.id)
                        }
                    ) {
                        Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Lightbulb, contentDescription = null, tint = SoftPurple)
                                Spacer(Modifier.width(8.dp))
                                Text(tip.category.label, color = SoftPurple)
                            }
                            Text(tip.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            if (expanded) {
                                Text(tip.body, color = TextSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GroupsDialog(groupsViewModel: GroupsViewModel, onDismiss: () -> Unit) {
    val uiState by groupsViewModel.uiState.collectAsStateWithLifecycle()
    var showCreate by rememberSaveable { mutableStateOf(false) }
    var addMemberTarget by remember { mutableStateOf<StressGroup?>(null) }
    LaunchedEffect(Unit) { groupsViewModel.load() }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text("Close") } },
        dismissButton = { TextButton(onClick = { showCreate = true }) { Text("Create") } },
        title = { Text("Groups") },
        text = {
            if (uiState.groups.isEmpty()) {
                Text("No Groups Yet", color = TextSecondary)
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    uiState.groups.forEach { group ->
                        Card {
                            Column(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(group.name, fontWeight = FontWeight.SemiBold)
                                Text("${group.memberIds.size} members", color = TextSecondary)
                                uiState.stats[group.id]?.avgStress?.let {
                                    Text("Avg stress: ${it.toInt()}", color = TextSecondary)
                                }
                                TextButton(onClick = { addMemberTarget = group }) { Text("Add member") }
                            }
                        }
                    }
                }
            }
        }
    )

    if (showCreate) {
        SimpleInputDialog(
            title = "Create Group",
            label = "Group Name",
            onDismiss = { showCreate = false },
            onConfirm = {
                groupsViewModel.createGroup(it)
                showCreate = false
            }
        )
    }

    addMemberTarget?.let { group ->
        SimpleInputDialog(
            title = "Add Member",
            label = "User ID",
            onDismiss = { addMemberTarget = null },
            onConfirm = { memberId ->
                groupsViewModel.addMember(group, memberId)
                addMemberTarget = null
            }
        )
    }
}

@Composable
private fun SimpleInputDialog(
    title: String,
    label: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var value by rememberSaveable { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = { onConfirm(value) }, enabled = value.isNotBlank()) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        title = { Text(title) },
        text = { OutlinedTextField(value = value, onValueChange = { value = it }, label = { Text(label) }) }
    )
}

private fun greetingText(): String {
    val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
    return when {
        hour < 12 -> "Good morning,"
        hour < 17 -> "Good afternoon,"
        else -> "Good evening,"
    }
}

private fun formatDate(date: Date): String =
    SimpleDateFormat("MMMM d, yyyy", Locale.US).format(date)

private fun formatTime(date: Date): String =
    SimpleDateFormat("h:mm a", Locale.US).format(date)

private fun relativeTime(date: Date): String {
    val diffMs = System.currentTimeMillis() - date.time
    val minutes = diffMs / 60_000
    return when {
        minutes < 1 -> "Just now"
        minutes < 60 -> "${minutes}m ago"
        minutes < 1_440 -> "${minutes / 60}h ago"
        else -> "${minutes / 1_440}d ago"
    }
}
