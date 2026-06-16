package com.example

import android.app.Application
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.*
import com.example.ui.Translations
import com.example.ui.theme.MyApplicationTheme
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val app = application as SiAbsenApplication
        val repository = app.repository

        setContent {
            val viewModel: SiAbsenViewModel by viewModels {
                SiAbsenViewModelFactory(application, repository)
            }

            val isDarkMode by viewModel.isDarkMode.collectAsState()

            MyApplicationTheme(darkTheme = isDarkMode) {
                Scaffold(
                    modifier = Modifier
                        .fillMaxSize()
                        .testTag("main_scaffold")
                ) { innerPadding ->
                    MainScreen(
                        viewModel = viewModel,
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }
}

@Composable
fun MainScreen(viewModel: SiAbsenViewModel, modifier: Modifier = Modifier) {
    val lang by viewModel.language.collectAsState()
    val isDarkMode by viewModel.isDarkMode.collectAsState()
    val currentRole by viewModel.currentRole.collectAsState()
    val selectedTenantId by viewModel.selectedTenantId.collectAsState()
    val tenants by viewModel.tenants.collectAsState()
    val activeNotifications by viewModel.activeNotifications.collectAsState()

    val currentTenant = tenants.find { it.id == selectedTenantId } ?: Tenant("t-01", "GlowTech Indonesia", "glowtech.com", "api_key_gt_990172_secured", "Active", System.currentTimeMillis())

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Main Scrollable Area
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            // Header Bar
            HeaderSection(
                viewModel = viewModel,
                lang = lang,
                isDarkMode = isDarkMode
            )

            // Top Quick Selector: Tenants (SaaS Multi-tenancy) & Roles
            TenantAndRoleSelector(
                viewModel = viewModel,
                tenants = tenants,
                selectedTenantId = selectedTenantId,
                currentRole = currentRole,
                lang = lang
            )

            // Dynamic Dashboard Content based on current switching role
            when (currentRole) {
                "Karyawan" -> DashboardKaryawan(viewModel = viewModel, lang = lang, tenantId = selectedTenantId)
                "HR" -> DashboardHR(viewModel = viewModel, lang = lang, tenantId = selectedTenantId)
                "Admin" -> DashboardAdmin(viewModel = viewModel, lang = lang, tenantId = selectedTenantId)
            }

            // Footer / AES Encrypted Motto
            FooterBranding(lang = lang, currentTenant = currentTenant)
        }

        // Live Mock Notification Popups on Top of Screen
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .padding(top = 16.dp, start = 16.dp, end = 16.dp)
        ) {
            AnimatedVisibility(
                visible = activeNotifications.isNotEmpty(),
                enter = slideInVertically() + fadeIn(),
                exit = slideOutVertically() + fadeOut()
            ) {
                activeNotifications.firstOrNull()?.let { activeNotif ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { viewModel.removeNotification(activeNotif.id) },
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                        ),
                        shape = RoundedCornerShape(16.dp),
                        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .padding(16.dp)
                                .fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.NotificationsActive,
                                contentDescription = "Webhook API sync status",
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(24.dp)
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = activeNotif.title,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = activeNotif.message,
                                    fontSize = 12.sp,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                            IconButton(onClick = { viewModel.removeNotification(activeNotif.id) }) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Close",
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun HeaderSection(
    viewModel: SiAbsenViewModel,
    lang: String,
    isDarkMode: Boolean
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        ),
        shape = RoundedCornerShape(24.dp)
    ) {
        Row(
            modifier = Modifier
                .padding(20.dp)
                .fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    text = Translations.getString("app_title", lang),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Black,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "SaaS Enterprise Cloud",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    letterSpacing = 1.sp,
                    color = MaterialTheme.colorScheme.primary
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                // Language Toggle Button
                IconButton(
                    onClick = { viewModel.toggleLanguage() },
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.secondaryContainer)
                ) {
                    Icon(
                        imageVector = Icons.Default.Language,
                        contentDescription = "Language",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp)
                    )
                }

                Spacer(modifier = Modifier.width(8.dp))

                // Dark Mode Toggle Button
                IconButton(
                    onClick = { viewModel.toggleDarkMode() },
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.secondaryContainer)
                ) {
                    Icon(
                        imageVector = if (isDarkMode) Icons.Default.LightMode else Icons.Default.DarkMode,
                        contentDescription = "Theme",
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

@Composable
fun TenantAndRoleSelector(
    viewModel: SiAbsenViewModel,
    tenants: List<Tenant>,
    selectedTenantId: String,
    currentRole: String,
    lang: String
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        // Tenant Selector
        Text(
            text = Translations.getString("tenant_select", lang),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.secondary,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            tenants.forEach { tenant ->
                val isSelected = tenant.id == selectedTenantId
                Card(
                    modifier = Modifier
                        .widthIn(min = 140.dp)
                        .clickable { viewModel.selectTenant(tenant.id) },
                    colors = CardDefaults.cardColors(
                        containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.secondaryContainer,
                        contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSecondaryContainer
                    ),
                    shape = RoundedCornerShape(16.dp),
                    border = BorderStroke(
                        width = 1.dp,
                        color = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent
                    )
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = if (tenant.status == "Active") Icons.Default.CloudQueue else Icons.Default.CloudOff,
                                contentDescription = "Cloud Status",
                                modifier = Modifier.size(14.dp),
                                tint = if (tenant.status == "Active") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = tenant.name,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                        Text(
                            text = tenant.domain,
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.secondary
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Role Selector Button Tabs
        Text(
            text = Translations.getString("role_select", lang),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.secondary,
            modifier = Modifier.padding(start = 4.dp, bottom = 6.dp)
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.secondaryContainer, RoundedCornerShape(16.dp))
                .padding(4.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            val roles = listOf(
                "Karyawan" to Translations.getString("employee", lang),
                "HR" to Translations.getString("hr_manager", lang),
                "Admin" to Translations.getString("sys_admin", lang)
            )

            roles.forEach { (roleKey, roleLabel) ->
                val isSelected = currentRole == roleKey
                Button(
                    onClick = { viewModel.selectRole(roleKey) },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                        contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                    ),
                    shape = RoundedCornerShape(12.dp),
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    modifier = Modifier
                        .weight(1f)
                        .testTag("role_tab_${roleKey}")
                ) {
                    Text(
                        text = roleLabel,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        maxLines = 1
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
    }
}

// -------------------------------------------------------------
// ROLE 1: DASHBOARD KARYAWAN (Employee Home View)
// -------------------------------------------------------------
@Composable
fun DashboardKaryawan(viewModel: SiAbsenViewModel, lang: String, tenantId: String) {
    val attendanceList by viewModel.attendanceList.collectAsState()
    val leaveRequests by viewModel.leaveRequests.collectAsState()

    val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    val todayStr = format.format(Date())

    // Check if user has already checked in today
    val todayRecord = attendanceList.find { it.dateString == todayStr && it.userId == "kar-08" }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {

        // Quick Clock In / Out Board
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .testTag("clock_card"),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = Icons.Default.Fingerprint,
                    contentDescription = "Presence fingerprint",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(48.dp)
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = Translations.getString("clock_in_out", lang),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = "System Zone: Jakarta/GMT+7",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.secondary
                )

                Spacer(modifier = Modifier.height(16.dp))

                if (todayRecord == null) {
                    // Two options: On-time or Late Checkin
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Button(
                            onClick = { viewModel.performCheckIn("Hadir") },
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                            modifier = Modifier
                                .weight(1f)
                                .height(48.dp)
                                .testTag("clock_in_ontime"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text(
                                text = Translations.getString("button_clock_in", lang),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        Button(
                            onClick = { viewModel.performCheckIn("Terlambat") },
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                            modifier = Modifier
                                .weight(1f)
                                .height(48.dp)
                                .testTag("clock_in_late"),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text(
                                text = "${Translations.getString("button_clock_in", lang)} (WFH/Late)",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                } else {
                    // Checked In. Offer Check Out if not already done
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "${Translations.getString("current_status", lang)}: ${todayRecord.status}",
                            fontWeight = FontWeight.Bold,
                            color = if (todayRecord.status == "Hadir") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error,
                            fontSize = 14.sp
                        )

                        Text(
                            text = "${Translations.getString("checked_in_at", lang)}: ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(todayRecord.checkInTime))}",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.secondary
                        )

                        todayRecord.checkOutTime?.let { outTime ->
                            Text(
                                text = "${Translations.getString("checked_out_at", lang)}: ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(outTime))}",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.secondary
                            )
                        }

                        Spacer(modifier = Modifier.height(12.dp))

                        if (todayRecord.checkOutTime == null) {
                            Button(
                                onClick = { viewModel.performCheckOut(todayRecord.id) },
                                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(48.dp)
                                    .testTag("clock_out_button"),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Text(
                                    text = Translations.getString("button_clock_out", lang),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 13.sp
                                )
                            }
                        }
                    }
                }
            }
        }

        // Submitting Permission & Leaves (Cuti & Izin)
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            val expandedDropdown = remember { mutableStateOf(false) }
            val leaveTypeSelected by viewModel.tempLeaveType.collectAsState()
            val leaveReason by viewModel.tempLeaveReason.collectAsState()
            val startDate by viewModel.tempLeaveStart.collectAsState()
            val endDate by viewModel.tempLeaveEnd.collectAsState()

            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = Translations.getString("submit_leave", lang),
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Divider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

                // Leave Type selector
                Box(modifier = Modifier.fillMaxWidth()) {
                    OutlinedButton(
                        onClick = { expandedDropdown.value = true },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(text = "${Translations.getString("leave_type", lang)}: $leaveTypeSelected")
                            Icon(imageVector = Icons.Default.ArrowDropDown, contentDescription = "Dropdown")
                        }
                    }
                    DropdownMenu(
                        expanded = expandedDropdown.value,
                        onDismissRequest = { expandedDropdown.value = false }
                    ) {
                        listOf("Cuti Tahunan", "Izin Sakit", "Izin Keagamaan", "Cuti Melahirkan").forEach { type ->
                            DropdownMenuItem(
                                text = { Text(text = type) },
                                onClick = {
                                    viewModel.tempLeaveType.value = type
                                    expandedDropdown.value = false
                                }
                            )
                        }
                    }
                }

                // Leave Dates input row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = startDate,
                        onValueChange = { viewModel.tempLeaveStart.value = it },
                        label = { Text(Translations.getString("start_date", lang), fontSize = 11.sp) },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = endDate,
                        onValueChange = { viewModel.tempLeaveEnd.value = it },
                        label = { Text(Translations.getString("end_date", lang), fontSize = 11.sp) },
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(12.dp),
                        singleLine = true
                    )
                }

                // Leave Reason text area
                OutlinedTextField(
                    value = leaveReason,
                    onValueChange = { viewModel.tempLeaveReason.value = it },
                    label = { Text(Translations.getString("leave_reason", lang)) },
                    placeholder = { Text(Translations.getString("reason_hint", lang)) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    maxLines = 3
                )

                // Submit button
                Button(
                    onClick = { viewModel.submitLeaveRequest() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    Text(
                        text = Translations.getString("button_submit_leave", lang),
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp
                    )
                }
            }
        }

        // Calendar Integration: Interactive custom drawn monthly grid view list
        CalendarWidget(viewModel = viewModel, lang = lang, attendanceList = attendanceList, leaveRequests = leaveRequests)

        // Upload custom medical certificate support with automatic AES Hash display
        DigitalDocsUploaderSection(viewModel = viewModel, lang = lang)
    }
}

// Interactive custom calendar dashboard widget
@Composable
fun CalendarWidget(
    viewModel: SiAbsenViewModel,
    lang: String,
    attendanceList: List<AttendanceRecord>,
    leaveRequests: List<LeaveRequest>
) {
    val selectedDay by viewModel.selectedCalendarDay.collectAsState()

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
        shape = RoundedCornerShape(24.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(
                text = Translations.getString("interactive_calendar", lang),
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "Juni 2026",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 12.dp)
            )

            // Header labels
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                listOf("S", "S", "R", "K", "J", "S", "M").forEach { heading ->
                    Text(
                        text = heading,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.secondary
                    )
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            // 30 days grid of June 2026 (starts on Monday)
            val chunkedDays = (1..30).chunked(7)
            chunkedDays.forEach { week ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    week.forEach { day ->
                        val isSelected = selectedDay == day

                        // Check status for indicators
                        val dayDateStr = "2026-06-%02d".format(day)
                        val matchedAttendance = attendanceList.filter { it.dateString == dayDateStr }
                        val isPresent = matchedAttendance.any { it.status == "Hadir" }
                        val isLate = matchedAttendance.any { it.status == "Terlambat" }

                        val matchedLeave = leaveRequests.filter {
                            dayDateStr >= it.startDate && dayDateStr <= it.endDate && it.status == "Disetujui"
                        }
                        val isLeave = matchedLeave.isNotEmpty()

                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .aspectRatio(1f)
                                .padding(2.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (isSelected) MaterialTheme.colorScheme.primary
                                    else if (isPresent) MaterialTheme.colorScheme.surfaceVariant
                                    else Color.Transparent
                                )
                                .clickable { viewModel.setCalendarDay(day) },
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    text = day.toString(),
                                    fontSize = 12.sp,
                                    fontWeight = if (isSelected) FontWeight.Black else FontWeight.Normal,
                                    color = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                                )

                                // Indicators circle dots
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(2.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    if (isPresent) {
                                        Box(
                                            modifier = Modifier
                                                .size(4.dp)
                                                .clip(CircleShape)
                                                .background(Color(0xFF386B1D))
                                        )
                                    }
                                    if (isLate) {
                                        Box(
                                            modifier = Modifier
                                                .size(4.dp)
                                                .clip(CircleShape)
                                                .background(Color(0xFFBA1A1A))
                                        )
                                    }
                                    if (isLeave) {
                                        Box(
                                            modifier = Modifier
                                                .size(4.dp)
                                                .clip(CircleShape)
                                                .background(Color(0xFFE29A09))
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Fill remaining empty columns if week isn't complete
                    if (week.size < 7) {
                        for (i in 1..(7 - week.size)) {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Calendar status description summary
            val currentDayDateStr = "2026-06-%02d".format(selectedDay)
            val focusedAttendance = attendanceList.filter { it.dateString == currentDayDateStr }
            val focusedLeaves = leaveRequests.filter { currentDayDateStr >= it.startDate && currentDayDateStr <= it.endDate }

            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                shape = RoundedCornerShape(12.dp)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "Detail: $currentDayDateStr",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary
                    )

                    if (focusedAttendance.isEmpty() && focusedLeaves.isEmpty()) {
                        Text(
                            text = Translations.getString("no_data", lang),
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.secondary
                        )
                    }

                    focusedAttendance.forEach { att ->
                        Text(
                            text = "• ${att.userName} (${Translations.getString("present", lang)} - ${att.status}) : In: ${SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(att.checkInTime))}",
                            fontSize = 11.sp
                        )
                    }

                    focusedLeaves.forEach { leave ->
                        Text(
                            text = "• ${leave.leaveType} [${leave.status}] : ${leave.reason}",
                            fontSize = 11.sp,
                            color = if (leave.status == "Disetujui") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.secondary
                        )
                    }
                }
            }
        }
    }
}

// -------------------------------------------------------------
// ENCRYPTED DIGITAL DOCUMENTS VIEWER & ARCHIVE UTILITY
// -------------------------------------------------------------
@Composable
fun DigitalDocsUploaderSection(viewModel: SiAbsenViewModel, lang: String) {
    val digitalDocs by viewModel.digitalDocs.collectAsState()
    val uploadTitle by viewModel.tempDocTitle.collectAsState()

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        shape = RoundedCornerShape(24.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Default.VerifiedUser,
                    contentDescription = "Shield Guard Indicator",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = Translations.getString("docs_archive", lang),
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Text(
                text = Translations.getString("saas_secure_motto", lang),
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.secondary,
                modifier = Modifier.padding(bottom = 12.dp)
            )

            // Submit input field
            OutlinedTextField(
                value = uploadTitle,
                onValueChange = { viewModel.tempDocTitle.value = it },
                placeholder = { Text(Translations.getString("doc_title_hint", lang), fontSize = 12.sp) },
                label = { Text(Translations.getString("upload_doc", lang), fontSize = 11.sp) },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                trailingIcon = {
                    IconButton(
                        onClick = { viewModel.uploadEncryptedDoc() },
                        modifier = Modifier.testTag("upload_shield_button")
                    ) {
                        Icon(imageVector = Icons.Default.Lock, contentDescription = "Encrypt and Upload", tint = MaterialTheme.colorScheme.primary)
                    }
                }
            )

            Spacer(modifier = Modifier.height(12.dp))

            // List of documents
            digitalDocs.forEach { doc ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = doc.title,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f)
                            )
                            Text(
                                text = doc.fileSize,
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.secondary
                            )
                        }

                        Spacer(modifier = Modifier.height(2.dp))

                        Text(
                            text = "${Translations.getString("hash_value", lang)}: ${doc.hashValue}...",
                            fontFamily = FontFamily.Monospace,
                            fontSize = 9.sp,
                            color = MaterialTheme.colorScheme.secondary
                        )

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.padding(top = 4.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF386B1D))
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "Fully Encrypted • AES-256",
                                fontSize = 9.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }
        }
    }
}

// -------------------------------------------------------------
// ROLE 2: DASHBOARD HR (Human Resources View Panel)
// -------------------------------------------------------------
@Composable
fun DashboardHR(viewModel: SiAbsenViewModel, lang: String, tenantId: String) {
    val attendanceList by viewModel.attendanceList.collectAsState()
    val leaveRequests by viewModel.leaveRequests.collectAsState()
    val exportingState by viewModel.exportingState.collectAsState()

    // Calculated metrics
    val totalEmployees = 6 // Mock registered count
    val cntPresent = attendanceList.count { it.status == "Hadir" }
    val cntLate = attendanceList.count { it.status == "Terlambat" }
    val cntLeave = leaveRequests.count { it.status == "Disetujui" }
    val cntAbsent = totalEmployees - (cntPresent + cntLate + cntLeave)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {

        // Manager Fast summary quick view card
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(28.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = Translations.getString("daily_summary", lang),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = Translations.getString("fast_summary", lang),
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.secondary
                        )
                    }
                    Box(
                        modifier = Modifier
                            .background(MaterialTheme.colorScheme.primary, CircleShape)
                            .padding(horizontal = 12.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = "LIVE NOW",
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    SummaryMetricBadge(
                        value = cntPresent.toString(),
                        label = Translations.getString("present", lang),
                        modifier = Modifier.weight(1f)
                    )
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(32.dp)
                            .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                    )
                    SummaryMetricBadge(
                        value = cntLate.toString(),
                        label = Translations.getString("late", lang),
                        modifier = Modifier.weight(1f)
                    )
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(32.dp)
                            .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                    )
                    SummaryMetricBadge(
                        value = cntLeave.toString(),
                        label = Translations.getString("on_leave", lang),
                        modifier = Modifier.weight(1f)
                    )
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(32.dp)
                            .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                    )
                    SummaryMetricBadge(
                        value = if (cntAbsent < 0) "0" else cntAbsent.toString(),
                        label = Translations.getString("absent", lang),
                        modifier = Modifier.weight(1f),
                        isError = true
                    )
                }
            }
        }

        // Export Report Module Action Button Card (PDF & Excel)
        ExportReportActionCard(viewModel = viewModel, lang = lang, exportingState = exportingState)

        // Pending Leave Approvals Section
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = Translations.getString("pending_leaves", lang),
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(10.dp))

                val pendingList = leaveRequests.filter { it.status == "Pending" }
                if (pendingList.isEmpty()) {
                    Text(
                        text = Translations.getString("no_leaves", lang),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.secondary,
                        modifier = Modifier.fillMaxWidth(),
                        textAlign = TextAlign.Center
                    )
                } else {
                    pendingList.forEach { pendingLeave ->
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
                            shape = RoundedCornerShape(16.dp)
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text(
                                        text = pendingLeave.userName,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = pendingLeave.leaveType,
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                }
                                Text(
                                    text = "Range: ${pendingLeave.startDate} — ${pendingLeave.endDate}",
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.secondary
                                )
                                Text(
                                    text = pendingLeave.reason,
                                    fontSize = 11.sp,
                                    modifier = Modifier.padding(vertical = 6.dp)
                                )

                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Button(
                                        onClick = { viewModel.processLeaveStatus(pendingLeave.id, "Disetujui", pendingLeave.leaveType) },
                                        shape = RoundedCornerShape(8.dp),
                                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                                        modifier = Modifier
                                            .weight(1f)
                                            .height(36.dp)
                                            .testTag("leave_approve_${pendingLeave.id}"),
                                        contentPadding = PaddingValues(0.dp)
                                    ) {
                                        Text(Translations.getString("approve", lang), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                    }

                                    OutlinedButton(
                                        onClick = { viewModel.processLeaveStatus(pendingLeave.id, "Ditolak", pendingLeave.leaveType) },
                                        shape = RoundedCornerShape(8.dp),
                                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.error),
                                        colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                                        modifier = Modifier
                                            .weight(1f)
                                            .height(36.dp)
                                            .testTag("leave_reject_${pendingLeave.id}"),
                                        contentPadding = PaddingValues(0.dp)
                                    ) {
                                        Text(Translations.getString("reject", lang), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Automatic attendance list rekapitulasi data kehadiran
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = Translations.getString("recent_activity", lang),
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(12.dp))

                attendanceList.forEach { record ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Profile initial circle
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.secondaryContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = record.userName.take(2).uppercase(),
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary,
                                fontSize = 12.sp
                            )
                        }

                        Spacer(modifier = Modifier.width(12.dp))

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = record.userName,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                text = "In: ${SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(record.checkInTime))} • ${record.locationIn.take(28)}...",
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.secondary
                            )
                        }

                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    if (record.status == "Hadir") MaterialTheme.colorScheme.primaryContainer
                                    else MaterialTheme.colorScheme.errorContainer
                                )
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = record.status,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (record.status == "Hadir") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                            )
                        }
                    }
                    Divider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.1f))
                }
            }
        }
    }
}

@Composable
fun SummaryMetricBadge(
    value: String,
    label: String,
    modifier: Modifier = Modifier,
    isError: Boolean = false
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = value,
            fontSize = 24.sp,
            fontWeight = FontWeight.Black,
            color = if (isError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = label.uppercase(),
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.secondary,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
fun ExportReportActionCard(
    viewModel: SiAbsenViewModel,
    lang: String,
    exportingState: ExportState
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
        shape = RoundedCornerShape(24.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(
                text = Translations.getString("export_report", lang),
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = Translations.getString("select_format", lang),
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.secondary,
                modifier = Modifier.padding(bottom = 12.dp)
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Button(
                    onClick = { viewModel.startExportReport("pdf") },
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .testTag("export_pdf_button"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    Icon(imageVector = Icons.Default.PictureAsPdf, contentDescription = "PDF icon", modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(Translations.getString("btn_export_pdf", lang), fontSize = 11.sp)
                }

                Button(
                    onClick = { viewModel.startExportReport("xlsx") },
                    modifier = Modifier
                        .weight(1f)
                        .height(44.dp)
                        .testTag("export_xlsx_button"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondaryContainer, contentColor = MaterialTheme.colorScheme.primary),
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary)
                ) {
                    Icon(imageVector = Icons.Default.TableChart, contentDescription = "Excel icon", modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(Translations.getString("btn_export_xlsx", lang), fontSize = 11.sp)
                }
            }

            // Export feedback states
            AnimatedVisibility(visible = exportingState != ExportState.Idle) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp)
                ) {
                    when (exportingState) {
                        is ExportState.Processing -> {
                            Text(
                                text = "Encoding document records: ${exportingState.progress}% ...",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            LinearProgressIndicator(
                                progress = { exportingState.progress.toFloat() / 100f },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = 6.dp)
                                    .clip(RoundedCornerShape(4.dp)),
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        is ExportState.Success -> {
                            val context = LocalContext.current
                            Card(
                                modifier = Modifier.fillMaxWidth(),
                                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                                shape = RoundedCornerShape(12.dp)
                            ) {
                                Row(
                                    modifier = Modifier
                                        .padding(12.dp)
                                        .fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = "Ready to Share",
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 11.sp,
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                        Text(
                                            text = exportingState.fileName,
                                            fontSize = 10.sp,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    }

                                    Row {
                                        IconButton(onClick = {
                                            Toast.makeText(context, "Locating saved file paths successfully", Toast.LENGTH_SHORT).show()
                                        }) {
                                            Icon(imageVector = Icons.Default.Share, contentDescription = "Share Report", tint = MaterialTheme.colorScheme.primary)
                                        }
                                        IconButton(onClick = { viewModel.dismissExport() }) {
                                            Icon(imageVector = Icons.Default.Close, contentDescription = "Dismiss", tint = MaterialTheme.colorScheme.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        else -> {}
                    }
                }
            }
        }
    }
}

// -------------------------------------------------------------
// ROLE 3: DASHBOARD ADMIN (SaaS Multi-tenancy & Developer APIs)
// -------------------------------------------------------------
@Composable
fun DashboardAdmin(viewModel: SiAbsenViewModel, lang: String, tenantId: String) {
    val tenants by viewModel.tenants.collectAsState()
    val apiLogs by viewModel.apiLogs.collectAsState()
    val activeMetricType by viewModel.activeMetricType.collectAsState()

    // Administrative form inputs
    val tenantNameInput by viewModel.tempTenantName.collectAsState()
    val tenantDomainInput by viewModel.tempTenantDomain.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {

        // Real-Time Customizable Analytics Dashboard Graph Canvas representation
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text(
                    text = Translations.getString("analytics_dashboard", lang),
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "Operational KPIs (Interactive)",
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.padding(bottom = 12.dp)
                )

                // Tab selection
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    listOf("Punctuality" to "Ketepatan", "Work Hours" to "Durasi", "Absence Rate" to "Absen").forEach { (type, label) ->
                        val isSelected = activeMetricType == type
                        OutlinedButton(
                            onClick = { viewModel.activeMetricType.value = type },
                            colors = ButtonDefaults.outlinedButtonColors(
                                containerColor = if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                                contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary
                            ),
                            shape = RoundedCornerShape(10.dp),
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                            modifier = Modifier
                                .weight(1f)
                                .height(32.dp)
                        ) {
                            Text(label, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }

                // Custom charts: drawn with styled boxes to form percentages
                val metrics = when (activeMetricType) {
                    "Punctuality" -> listOf(
                        "On-Time" to 92f,
                        "Late" to 8f
                    )
                    "Work Hours" -> listOf(
                        "Overtime" to 15f,
                        "Standard" to 75f,
                        "Deficit" to 10f
                    )
                    else -> listOf(
                        "Present" to 88f,
                        "Leaves Approved" to 10f,
                        "Unexcused" to 2f
                    )
                }

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    metrics.forEach { (statName, rawPercent) ->
                        Column {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(text = statName, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                                Text(text = "${rawPercent.toInt()}%", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                            }
                            Spacer(modifier = Modifier.height(2.dp))
                            // Chart bar
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(10.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.secondaryContainer)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth(rawPercent / 100f)
                                        .fillMaxHeight()
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.primary)
                                )
                            }
                        }
                    }
                }
            }
        }

        // Multi-Tenant Management Board
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(imageVector = Icons.Default.Business, contentDescription = "Tenants", tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = Translations.getString("tenant_management", lang),
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))

                // Create Tenant Form Fields
                OutlinedTextField(
                    value = tenantNameInput,
                    onValueChange = { viewModel.tempTenantName.value = it },
                    label = { Text(Translations.getString("tenant_name", lang), fontSize = 11.sp) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )
                Spacer(modifier = Modifier.height(4.dp))
                OutlinedTextField(
                    value = tenantDomainInput,
                    onValueChange = { viewModel.tempTenantDomain.value = it },
                    label = { Text(Translations.getString("tenant_domain", lang), fontSize = 11.sp) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true
                )
                Spacer(modifier = Modifier.height(8.dp))

                Button(
                    onClick = { viewModel.createTenant() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(46.dp)
                        .testTag("add_tenant_button"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    Text(Translations.getString("btn_add_tenant", lang), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }

                Spacer(modifier = Modifier.height(14.dp))

                // Existing List with suspension toggling
                tenants.forEach { t ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .padding(12.dp)
                                .fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(text = t.name, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                Text(text = t.domain, fontSize = 10.sp, color = MaterialTheme.colorScheme.secondary)
                                Text(
                                    text = "Key: ${t.apiKey.take(14)}...",
                                    fontSize = 9.sp,
                                    fontFamily = FontFamily.Monospace,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }

                            Button(
                                onClick = { viewModel.toggleTenantStatus(t) },
                                shape = RoundedCornerShape(8.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = if (t.status == "Active") MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                                ),
                                contentPadding = PaddingValues(horizontal = 8.dp),
                                modifier = Modifier.height(28.dp)
                            ) {
                                Text(
                                    text = if (t.status == "Active") "ACTIVE" else "SUSPENDED",
                                    fontSize = 9.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }
        }

        // Real-Time Webhook/API Sync Tester Tool
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
            shape = RoundedCornerShape(24.dp)
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(imageVector = Icons.Default.SettingsEthernet, contentDescription = "API", tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = Translations.getString("api_endpoint_sync", lang),
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Verify corporate ecosystem CRM, ERP or HR systems integration with active webhook payload logs.",
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.padding(bottom = 12.dp)
                )

                Button(
                    onClick = { viewModel.triggerApiWebhookSync() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .testTag("webhook_sync_btn"),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                ) {
                    Icon(imageVector = Icons.Default.Refresh, contentDescription = "Sync Now")
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(Translations.getString("btn_trigger_sync", lang), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }

                Spacer(modifier = Modifier.height(14.dp))

                Text(
                    text = Translations.getString("api_log_head", lang),
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.padding(bottom = 6.dp)
                )

                // Listed api logs from DB
                apiLogs.forEach { log ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Column(modifier = Modifier.padding(10.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .background(
                                                if (log.method == "POST") Color(0xFF386B1D) else Color(0xFF1E88E5),
                                                RoundedCornerShape(4.dp)
                                            )
                                            .padding(horizontal = 4.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            text = log.method,
                                            fontSize = 8.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = Color.White
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        text = log.endpoint,
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }

                                Text(
                                    text = log.status.toString(),
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = if (log.status in 200..299) Color(0xFF386B1D) else Color(0xFFBA1A1A)
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "Payload: ${log.payload}",
                                fontSize = 9.sp,
                                fontFamily = FontFamily.Monospace,
                                color = MaterialTheme.colorScheme.secondary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun FooterBranding(lang: String, currentTenant: Tenant) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                imageVector = Icons.Default.Security,
                contentDescription = "Shield lock",
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = "Enterprise Node: AES-256 Cloud Isolated Mode",
                fontSize = 10.sp,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Bold
            )
        }

        Spacer(modifier = Modifier.height(4.dp))

        Text(
            text = "Active Tenant Signature: ${currentTenant.id.uppercase()} | key_hash=${currentTenant.apiKey.hashCode()}",
            fontFamily = FontFamily.Monospace,
            fontSize = 9.sp,
            color = MaterialTheme.colorScheme.secondary,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(20.dp))
    }
}
