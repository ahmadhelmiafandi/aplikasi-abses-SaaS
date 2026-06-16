package com.example

import android.app.Application
import androidx.room.Room
import com.example.data.AppDatabase
import com.example.data.AttendanceRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class SiAbsenApplication : Application() {

    private val applicationScope = CoroutineScope(SupervisorJob())

    val database by lazy {
        Room.databaseBuilder(
            this,
            AppDatabase::class.java,
            "siabsen_database"
        ).fallbackToDestructiveMigration().build()
    }

    val repository by lazy {
        AttendanceRepository(database.attendanceDao)
    }

    override fun onCreate() {
        super.onCreate()
        // Populate initial mock data on first run
        applicationScope.launch {
            repository.populateInitialDataIfEmpty()
        }
    }
}
