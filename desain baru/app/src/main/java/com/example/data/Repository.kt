package com.example.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AttendanceRepository(private val dao: AttendanceDao) {

    fun getAttendanceByTenant(tenantId: String): Flow<List<AttendanceRecord>> =
        dao.getAttendanceByTenant(tenantId)

    fun getAllAttendance(): Flow<List<AttendanceRecord>> = dao.getAllAttendance()

    suspend fun insertAttendance(record: AttendanceRecord) = dao.insertAttendance(record)

    suspend fun updateAttendance(record: AttendanceRecord) = dao.updateAttendance(record)

    fun getLeaveRequestsByTenant(tenantId: String): Flow<List<LeaveRequest>> =
        dao.getLeaveRequestsByTenant(tenantId)

    fun getAllLeaveRequests(): Flow<List<LeaveRequest>> = dao.getAllLeaveRequests()

    suspend fun insertLeaveRequest(request: LeaveRequest) = dao.insertLeaveRequest(request)

    suspend fun updateLeaveStatus(id: Int, status: String) = dao.updateLeaveStatus(id, status)

    fun getAllTenants(): Flow<List<Tenant>> = dao.getAllTenants()

    suspend fun insertTenant(tenant: Tenant) = dao.insertTenant(tenant)

    suspend fun deleteTenant(tenantId: String) = dao.deleteTenant(tenantId)

    fun getDigitalDocs(tenantId: String): Flow<List<DigitalDoc>> = dao.getDigitalDocs(tenantId)

    suspend fun insertDigitalDoc(doc: DigitalDoc) = dao.insertDigitalDoc(doc)

    fun getAllApiLogs(): Flow<List<ApiLog>> = dao.getAllApiLogs()

    suspend fun insertApiLog(log: ApiLog) = dao.insertApiLog(log)

    suspend fun populateInitialDataIfEmpty() {
        // Only run if database has no tenants
        val currentTenants = dao.getAllTenants().first()
        if (currentTenants.isNotEmpty()) return

        val now = System.currentTimeMillis()

        // Create Default Tenants (SaaS multi-tenancy)
        val tenants = listOf(
            Tenant("t-01", "GlowTech Indonesia", "glowtech.com", "api_key_gt_990172_secured", "Active", now),
            Tenant("t-02", "Nusantara Logistics", "nusantara-cargo.com", "api_key_nc_334511_secured", "Active", now - 86400000 * 2),
            Tenant("t-03", "AeroSpace Bandung", "aerospace.id", "api_key_ab_775199_secured", "Suspended", now - 86400000 * 10)
        )
        for (tenant in tenants) {
            dao.insertTenant(tenant)
        }

        // Create Default Attendance Records
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val records = listOf(
            // GloTech Indonesia records (t-01)
            AttendanceRecord(
                userId = "kar-01", userName = "Budi Hartono", userRole = "Karyawan", tenantId = "t-01",
                checkInTime = now - (11 * 3600000), // Checked-In 11 hours ago
                checkOutTime = now - (3 * 3600000), // Checked-Out 3 hours ago
                dateString = format.format(Date(now)), status = "Hadir",
                locationIn = "HQ Jakarta (-6.1754, 106.8272)", locationOut = "HQ Jakarta (-6.1754, 106.8272)",
                photoUrl = "https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200", isEncrypted = true
            ),
            AttendanceRecord(
                userId = "kar-02", userName = "Siti Rahma", userRole = "Karyawan", tenantId = "t-01",
                checkInTime = now - (105 * 100000), // Late check in
                checkOutTime = null,
                dateString = format.format(Date(now)), status = "Terlambat",
                locationIn = "Work From Home Bandung (-6.9175, 107.6191)", locationOut = null,
                photoUrl = "https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200", isEncrypted = true
            ),
            AttendanceRecord(
                userId = "kar-03", userName = "Dewi Lestari", userRole = "Karyawan", tenantId = "t-01",
                checkInTime = now - 86400000 - (12 * 3600000), // Yesterday
                checkOutTime = now - 86400000 - (4 * 3600000),
                dateString = format.format(Date(now - 86400000)), status = "Hadir",
                locationIn = "HQ Jakarta (-6.1754, 106.8272)", locationOut = "HQ Jakarta (-6.1754, 106.8272)",
                photoUrl = "https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=200", isEncrypted = true
            ),
            // Nusantara Logistics records (t-02)
            AttendanceRecord(
                userId = "kar-04", userName = "Andi Wijaya", userRole = "Karyawan", tenantId = "t-02",
                checkInTime = now - (11 * 3600000),
                checkOutTime = now - (4 * 3600000),
                dateString = format.format(Date(now)), status = "Hadir",
                locationIn = "Surabaya Depot (-7.2575, 112.7521)", locationOut = "Surabaya Depot (-7.2575, 112.7521)",
                photoUrl = "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?q=80&w=200", isEncrypted = true
            ),
            AttendanceRecord(
                userId = "kar-05", userName = "Fahmi Idris", userRole = "Karyawan", tenantId = "t-02",
                checkInTime = now - (3 * 3600000),
                checkOutTime = null,
                dateString = format.format(Date(now)), status = "Terlambat",
                locationIn = "Tangerang Hub (-6.1783, 106.6319)", locationOut = null,
                photoUrl = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200", isEncrypted = true
            )
        )
        for (record in records) {
            dao.insertAttendance(record)
        }

        // Create Default Leave Requests
        val leaveRequests = listOf(
            LeaveRequest(
                userId = "kar-03", userName = "Dewi Lestari", tenantId = "t-01",
                leaveType = "Cuti Tahunan", startDate = "2026-06-15", endDate = "2026-06-18",
                reason = "Acara pernikahan keluarga besar di Yogyakarta.", status = "Pending", createdAt = now
            ),
            LeaveRequest(
                userId = "kar-01", userName = "Budi Hartono", tenantId = "t-01",
                leaveType = "Izin Sakit", startDate = "2026-06-03", endDate = "2026-06-04",
                reason = "Demam tinggi dengan surat dokter terlampir.", status = "Disetujui", createdAt = now - 86400000 * 5
            ),
            LeaveRequest(
                userId = "kar-06", userName = "Anita Setia", tenantId = "t-01",
                leaveType = "Cuti Melahirkan", startDate = "2026-07-01", endDate = "2026-09-30",
                reason = "Cuti maternity sesuai rekomendasi dokter spesialis.", status = "Disetujui", createdAt = now - 86400000 * 8
            ),
            LeaveRequest(
                userId = "kar-04", userName = "Andi Wijaya", tenantId = "t-02",
                leaveType = "Cuti Keagamaan", startDate = "2026-06-25", endDate = "2026-06-27",
                reason = "Perayaan hari besar keagamaan di luar kota.", status = "Pending", createdAt = now - 3600000
            )
        )
        for (req in leaveRequests) {
            dao.insertLeaveRequest(req)
        }

        // Create Digital Encypted Documents
        val docs = listOf(
            DigitalDoc(
                title = "Legal_MOU_GlowTech_SaaS_2026.pdf", tenantId = "t-01", uploadedBy = "HR-Manager",
                fileSize = "240 KB", uploadedAt = now - (5 * 3600000), hashValue = "8f7c6e618badfbcbe508e7ff2"
            ),
            DigitalDoc(
                title = "Anonymized_Attendance_Salary_Recap_May.xlsx", tenantId = "t-01", uploadedBy = "HR-Analyst",
                fileSize = "1.2 MB", uploadedAt = now - 86400000, hashValue = "3f2e1a4d9e8751a007fbcde82"
            ),
            DigitalDoc(
                title = "Nusantara_NDA_Employee_Rules.pdf", tenantId = "t-02", uploadedBy = "Ops-Admin",
                fileSize = "410 KB", uploadedAt = now, hashValue = "d5c4b3a209e87123bcdef012"
            )
        )
        for (doc in docs) {
            dao.insertDigitalDoc(doc)
        }

        // Create API Integration Logs (to show activity)
        val logs = listOf(
            ApiLog(endpoint = "/v1/attendance/sync", method = "POST", timestamp = now - 1800000, status = 200, payload = "{ \"records_count\": 54, \"status\": \"success\" }"),
            ApiLog(endpoint = "/v1/employee/import", method = "POST", timestamp = now - 3600000, status = 201, payload = "{ \"inserted\": 12, \"updated\": 0 }"),
            ApiLog(endpoint = "/v1/tenants/status", method = "GET", timestamp = now - 7200000, status = 200, payload = "{ \"status\": \"healthy\", \"tenants\": [\"t-01\",\"t-02\",\"t-03\"] }"),
            ApiLog(endpoint = "/v1/webhooks/push", method = "POST", timestamp = now - 10800000, status = 500, payload = "{ \"error\": \"Connection Refused by endpoint raw.github...\" }")
        )
        for (log in logs) {
            dao.insertApiLog(log)
        }
    }
}
