package com.example.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "attendance_records")
data class AttendanceRecord(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val userId: String,
    val userName: String,
    val userRole: String,
    val tenantId: String,
    val checkInTime: Long,
    val checkOutTime: Long?,
    val dateString: String,
    val status: String, // Hadir, Terlambat, Izin, Cuti
    val locationIn: String,
    val locationOut: String?,
    val photoUrl: String,
    val isEncrypted: Boolean = true
)

@Entity(tableName = "leave_requests")
data class LeaveRequest(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val userId: String,
    val userName: String,
    val tenantId: String,
    val leaveType: String, // Cuti, Sakit, Izin
    val startDate: String,
    val endDate: String,
    val reason: String,
    val status: String, // Pending, Disetujui, Ditolak
    val createdAt: Long
)

@Entity(tableName = "tenants")
data class Tenant(
    @PrimaryKey val id: String,
    val name: String,
    val domain: String,
    val apiKey: String,
    val status: String, // Active, Suspended
    val createdAt: Long
)

@Entity(tableName = "digital_docs")
data class DigitalDoc(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val title: String,
    val tenantId: String,
    val uploadedBy: String,
    val uploadedAt: Long,
    val hashValue: String,
    val fileSize: String = "120 KB",
    val encryptionAlg: String = "AES-256",
    val status: String = "Encrypted"
)

@Entity(tableName = "api_logs")
data class ApiLog(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val endpoint: String,
    val method: String,
    val timestamp: Long,
    val status: Int,
    val payload: String
)

@Dao
interface AttendanceDao {
    @Query("SELECT * FROM attendance_records ORDER BY checkInTime DESC")
    fun getAllAttendance(): Flow<List<AttendanceRecord>>

    @Query("SELECT * FROM attendance_records WHERE tenantId = :tenantId ORDER BY checkInTime DESC")
    fun getAttendanceByTenant(tenantId: String): Flow<List<AttendanceRecord>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAttendance(record: AttendanceRecord)

    @Update
    suspend fun updateAttendance(record: AttendanceRecord)

    // Leave requests
    @Query("SELECT * FROM leave_requests ORDER BY createdAt DESC")
    fun getAllLeaveRequests(): Flow<List<LeaveRequest>>

    @Query("SELECT * FROM leave_requests WHERE tenantId = :tenantId ORDER BY createdAt DESC")
    fun getLeaveRequestsByTenant(tenantId: String): Flow<List<LeaveRequest>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLeaveRequest(request: LeaveRequest)

    @Query("UPDATE leave_requests SET status = :status WHERE id = :id")
    suspend fun updateLeaveStatus(id: Int, status: String)

    // Tenants
    @Query("SELECT * FROM tenants")
    fun getAllTenants(): Flow<List<Tenant>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTenant(tenant: Tenant)

    @Query("DELETE FROM tenants WHERE id = :tenantId")
    suspend fun deleteTenant(tenantId: String)

    // Digital Docs
    @Query("SELECT * FROM digital_docs WHERE tenantId = :tenantId ORDER BY uploadedAt DESC")
    fun getDigitalDocs(tenantId: String): Flow<List<DigitalDoc>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDigitalDoc(doc: DigitalDoc)

    // API logs
    @Query("SELECT * FROM api_logs ORDER BY timestamp DESC")
    fun getAllApiLogs(): Flow<List<ApiLog>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertApiLog(log: ApiLog)
}

@Database(
    entities = [
        AttendanceRecord::class,
        LeaveRequest::class,
        Tenant::class,
        DigitalDoc::class,
        ApiLog::class
    ],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract val attendanceDao: AttendanceDao
}
