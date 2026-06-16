package com.example

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.data.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class SiAbsenViewModel(application: Application, private val repository: AttendanceRepository) : AndroidViewModel(application) {

    // Language Toggle: "id" (Indonesian), "en" (English)
    private val _language = MutableStateFlow("id")
    val language: StateFlow<String> = _language.asStateFlow()

    // Dark Mode Toggle
    private val _isDarkMode = MutableStateFlow(false)
    val isDarkMode: StateFlow<Boolean> = _isDarkMode.asStateFlow()

    // Current Role switcher: "Karyawan", "HR", "Admin"
    private val _currentRole = MutableStateFlow("Karyawan")
    val currentRole: StateFlow<String> = _currentRole.asStateFlow()

    // SaaS Multi-tenancy: current selected Tenant
    private val _selectedTenantId = MutableStateFlow("t-01")
    val selectedTenantId: StateFlow<String> = _selectedTenantId.asStateFlow()

    // Active notifications popup list (mimicking push updates)
    private val _activeNotifications = MutableStateFlow<List<AppNotification>>(emptyList())
    val activeNotifications: StateFlow<List<AppNotification>> = _activeNotifications.asStateFlow()

    // UI state inputs for Karyawan / Employee
    val checkInPhotoUrl = MutableStateFlow("https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200")
    val tempLeaveType = MutableStateFlow("Cuti Tahunan")
    val tempLeaveReason = MutableStateFlow("")
    val tempLeaveStart = MutableStateFlow("2026-06-12")
    val tempLeaveEnd = MutableStateFlow("2026-06-15")

    // UI state inputs for HR / Administrator
    val tempTenantName = MutableStateFlow("")
    val tempTenantDomain = MutableStateFlow("")
    val tempTenantApiKey = MutableStateFlow("")
    val tempDocTitle = MutableStateFlow("")

    // Expose DB logs
    val tenants: StateFlow<List<Tenant>> = repository.getAllTenants()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Filter attendance by tenantId (Multi-tenancy isolation)
    val attendanceList: StateFlow<List<AttendanceRecord>> = _selectedTenantId.flatMapLatest { tenantId ->
        repository.getAttendanceByTenant(tenantId)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Filter leaves by tenantId
    val leaveRequests: StateFlow<List<LeaveRequest>> = _selectedTenantId.flatMapLatest { tenantId ->
        repository.getLeaveRequestsByTenant(tenantId)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // All Digital Documents for a tenant
    val digitalDocs: StateFlow<List<DigitalDoc>> = _selectedTenantId.flatMapLatest { tenantId ->
        repository.getDigitalDocs(tenantId)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Developer API Logs
    val apiLogs: StateFlow<List<ApiLog>> = repository.getAllApiLogs()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // Calendar logic: focussed month calendar state (simulating June 2026)
    private val _selectedCalendarDay = MutableStateFlow(8) // Default is today
    val selectedCalendarDay: StateFlow<Int> = _selectedCalendarDay.asStateFlow()

    // Dynamic Customizable Analytics Settings
    val activeMetricType = MutableStateFlow("Punctuality") // "Punctuality", "Work Hours", "Absence Rate"

    // Mock Exporting Progress
    private val _exportingState = MutableStateFlow<ExportState>(ExportState.Idle)
    val exportingState: StateFlow<ExportState> = _exportingState.asStateFlow()

    fun toggleLanguage() {
        _language.value = if (_language.value == "id") "en" else "id"
        postNotification(
            title = if (_language.value == "id") "Bahasa Berubah" else "Language Changed",
            message = if (_language.value == "id") "Aplikasi sekarang menggunakan Bahasa Indonesia." else "Application language changed to English."
        )
    }

    fun toggleDarkMode() {
        _isDarkMode.value = !_isDarkMode.value
        postNotification(
            title = if (_language.value == "id") "Tema Berubah" else "Theme Toggled",
            message = if (_language.value == "id") "Mode Gelap diaktifkan untuk kenyamanan mata." else "Dark Mode toggled for eye-comfort."
        )
    }

    fun selectRole(role: String) {
        _currentRole.value = role
        postNotification(
            title = if (_language.value == "id") "Akses Peran Diubah" else "User Role Switched",
            message = if (_language.value == "id") "Beralih ke dasbor $role secara langsung." else "Switched directly to $role dashboard."
        )
    }

    fun selectTenant(tenantId: String) {
        _selectedTenantId.value = tenantId
        postNotification(
            title = if (_language.value == "id") "Workspace Tenant Berubah" else "Workspace Tenant Switched",
            message = if (_language.value == "id") "Memuat data dan enkripsi untuk tenant $tenantId." else "Loading assets and schemas for tenant $tenantId."
        )
    }

    fun setCalendarDay(day: Int) {
        _selectedCalendarDay.value = day
    }

    // Interactive Employee Check In Action
    fun performCheckIn(statusText: String) {
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val dateStr = format.format(Date(now))
            val currentTenant = _selectedTenantId.value

            val coords = if (statusText == "Terlambat") {
                "Work From Home Bandung (-6.9175, 107.6191)"
            } else {
                "HQ Jakarta (-6.1754, 106.8272)"
            }

            val newRecord = AttendanceRecord(
                userId = "kar-08",
                userName = "Helmi Afandi",
                userRole = "Karyawan",
                tenantId = currentTenant,
                checkInTime = now,
                checkOutTime = null,
                dateString = dateStr,
                status = statusText,
                locationIn = coords,
                locationOut = null,
                photoUrl = checkInPhotoUrl.value
            )
            repository.insertAttendance(newRecord)

            postNotification(
                title = if (_language.value == "id") "Presensi Berhasil!" else "Clock-In Successful!",
                message = if (_language.value == "id") "Masuk pada pukul ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(now))} ($statusText)" else "Logged in at ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(now))} ($statusText)"
            )
        }
    }

    // Interactive Employee Check Out Action
    fun performCheckOut(recordId: Int) {
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            // Find current active attendance
            val currentList = attendanceList.value
            val match = currentList.find { it.id == recordId }
            if (match != null) {
                val updated = match.copy(
                    checkOutTime = now,
                    locationOut = "HQ Jakarta (-6.1754, 106.8272)"
                )
                repository.updateAttendance(updated)

                postNotification(
                    title = if (_language.value == "id") "Presensi Pulang Berhasil!" else "Clock-Out Successful!",
                    message = if (_language.value == "id") "Pulang pada pukul ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(now))}" else "Logged out at ${SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date(now))}"
                )
            }
        }
    }

    // Interactive Submit Leave Request Action
    fun submitLeaveRequest() {
        if (tempLeaveReason.value.isBlank()) return
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            val newRequest = LeaveRequest(
                userId = "kar-08",
                userName = "Helmi Afandi",
                tenantId = _selectedTenantId.value,
                leaveType = tempLeaveType.value,
                startDate = tempLeaveStart.value,
                endDate = tempLeaveEnd.value,
                reason = tempLeaveReason.value,
                status = "Pending",
                createdAt = now
            )
            repository.insertLeaveRequest(newRequest)
            tempLeaveReason.value = "" // Reset form

            postNotification(
                title = if (_language.value == "id") "Pengajuan Izin Dikirim" else "Leave Request Submitted",
                message = if (_language.value == "id") "Pengajuan ${tempLeaveType.value} sedang ditinjau oleh HR." else "Requested ${tempLeaveType.value} under HR approval process."
            )
        }
    }

    // HR - Modify Leave Status (Approve or Reject)
    fun processLeaveStatus(id: Int, status: String, label: String) {
        viewModelScope.launch {
            repository.updateLeaveStatus(id, status)
            postNotification(
                title = if (_language.value == "id") "Pembaruan Status Cuti" else "Leave Status Updated",
                message = if (_language.value == "id") "Pengajuan cuti telah diperbarui menjadi: $status" else "The leave proposal has been updated to: $status"
            )
        }
    }

    // Admin - Create a new Tenant (SaaS Expansion)
    fun createTenant() {
        if (tempTenantName.value.isBlank() || tempTenantDomain.value.isBlank()) return
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            val randomId = "t-0" + (tenants.value.size + 1)
            val generatedApiKey = "api_key_" + tempTenantDomain.value.replace(".", "_") + "_${(1000..9999).random()}_secured"

            val newTenant = Tenant(
                id = randomId,
                name = tempTenantName.value,
                domain = tempTenantDomain.value,
                apiKey = tempTenantApiKey.value.ifBlank { generatedApiKey },
                status = "Active",
                createdAt = now
            )
            repository.insertTenant(newTenant)

            // Clear inputs
            tempTenantName.value = ""
            tempTenantDomain.value = ""
            tempTenantApiKey.value = ""

            postNotification(
                title = if (_language.value == "id") "Tenant Baru Ditambahkan" else "New Tenant Added",
                message = if (_language.value == "id") "Tenant ${newTenant.name} berhasil diisolasi di cloud SaaS." else "Tenant ${newTenant.name} isolated successfully on Multi-tenant Cloud."
            )
        }
    }

    // Toggle Tenant Status Active <-> Suspended
    fun toggleTenantStatus(tenant: Tenant) {
        viewModelScope.launch {
            val updatedStatus = if (tenant.status == "Active") "Suspended" else "Active"
            val updated = tenant.copy(status = updatedStatus)
            repository.insertTenant(updated)

            postNotification(
                title = if (_language.value == "id") "Status Tenant Diubah" else "Tenant Status Alternated",
                message = if (_language.value == "id") "SaaS Tenant ${tenant.name} sekarang: $updatedStatus" else "SaaS Tenant ${tenant.name} is now: $updatedStatus"
            )
        }
    }

    // HR - Upload encrypted document
    fun uploadEncryptedDoc() {
        if (tempDocTitle.value.isBlank()) return
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            // Simulating real-time SHA-256 calculation
            val rawString = tempDocTitle.value + now.toString()
            val md = MessageDigest.getInstance("SHA-256")
            val digest = md.digest(rawString.toByteArray())
            val hexHash = digest.fold("") { str, it -> str + "%02x".format(it) }.take(24)

            val newDoc = DigitalDoc(
                title = tempDocTitle.value,
                tenantId = _selectedTenantId.value,
                uploadedBy = if (currentRole.value == "Karyawan") "Karyawan-Helmi" else "HR-Manager",
                fileSize = "${(120..4900).random()} KB",
                uploadedAt = now,
                hashValue = hexHash
            )
            repository.insertDigitalDoc(newDoc)
            tempDocTitle.value = ""

            postNotification(
                title = if (_language.value == "id") "Dokumen Terenkripsi Tersimpan" else "Encrypted File Saved",
                message = if (_language.value == "id") "File disimpan dengan algoritma kriptografi AES-256." else "File archived using verified cryptography AES-256."
            )
        }
    }

    // Third-party API Integration Syncing (Simulated Endpoint call & DB audit trail)
    fun triggerApiWebhookSync() {
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            val isSuccess = (1..10).random() != 10 // 90% success rate
            val status = if (isSuccess) 200 else 500
            val payload = if (isSuccess) {
                "{ \"source\": \"third_party_cron\", \"synchronized\": 8, \"skipped\": 1, \"status\": \"fully_synced_ok\" }"
            } else {
                "{ \"error\": \"Connection Refused by CRM server node v3\", \"status\": \"err_failure\" }"
            }

            val newLog = ApiLog(
                endpoint = "/v1/external/sync-pulse",
                method = "POST",
                timestamp = now,
                status = status,
                payload = payload
            )
            repository.insertApiLog(newLog)

            postNotification(
                title = if (_language.value == "id") "Web API Sinkronisasi Terpicu" else "Web API Sync Executed",
                message = if (_language.value == "id") "Status sinkronisasi: $status. Detail tersimpan dalam catatan pengembang." else "Sync status returned $status. Logs saved safely inside system auditable logs."
            )
        }
    }

    // Simulated Export PDF / Excel Process
    fun startExportReport(formatType: String) {
        viewModelScope.launch {
            _exportingState.value = ExportState.Processing(0)
            for (progress in 20..100 step 20) {
                kotlinx.coroutines.delay(200)
                _exportingState.value = ExportState.Processing(progress)
            }
            val fileName = "Rekap_Kehadiran_Absen_SaaS_${_selectedTenantId.value}_June2026.$formatType"
            _exportingState.value = ExportState.Success(fileName)

            postNotification(
                title = if (_language.value == "id") "Laporan Berhasil Diekspor" else "Report Export Clean",
                message = if (_language.value == "id") "File $fileName siap diunduh atau dipublikasikan." else "File $fileName prepared and verified. Ready to share."
            )
        }
    }

    fun dismissExport() {
        _exportingState.value = ExportState.Idle
    }

    // Push local alert simulation
    private fun postNotification(title: String, message: String) {
        val newNotification = AppNotification(
            id = (1000..9999).random(),
            title = title,
            message = message,
            timestamp = System.currentTimeMillis()
        )
        _activeNotifications.value = listOf(newNotification) + _activeNotifications.value
    }

    fun removeNotification(id: Int) {
        _activeNotifications.value = _activeNotifications.value.filter { it.id != id }
    }
}

// Help state models
data class AppNotification(
    val id: Int,
    val title: String,
    val message: String,
    val timestamp: Long
)

sealed class ExportState {
    object Idle : ExportState()
    data class Processing(val progress: Int) : ExportState()
    data class Success(val fileName: String) : ExportState()
}

// Factory to instantiate viewmodel securely pass repository
class SiAbsenViewModelFactory(private val application: Application, private val repository: AttendanceRepository) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(SiAbsenViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return SiAbsenViewModel(application, repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
