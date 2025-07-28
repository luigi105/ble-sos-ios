package com.miempresa.ble_sos_ap

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.Manifest
import android.content.Context
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.KeyguardManager
import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import android.graphics.Color
import android.os.PowerManager
import android.content.ComponentName
import android.content.ServiceConnection
import android.os.IBinder
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val CALL_CHANNEL = "com.miempresa.ble_sos_ap/call"
    private val FOREGROUND_CHANNEL = "com.miempresa.ble_sos_ap/foreground"
    private val NOTIFICATION_CHANNEL = "com.miempresa.ble_sos_ap/notification"
    // ✅ NUEVO CANAL para comunicación de lifecycle
    private val LIFECYCLE_CHANNEL = "com.miempresa.ble_sos_ap/lifecycle"
    
    // IDs para las diferentes notificaciones
    private val SOS_NOTIFICATION_ID = 1
    private val BLE_DISCONNECTED_NOTIFICATION_ID = 101
    private val BLE_CONNECTED_NOTIFICATION_ID = 102
    private val LOCATION_CONFIRMED_NOTIFICATION_ID = 103
    private val LOCATION_FAILED_NOTIFICATION_ID = 104

    // ✅ NUEVA VARIABLE para controlar cierre permanente
    private var appIsClosingPermanently = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal para llamadas telefónicas (existente)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "callNumber") {
                val phoneNumber = call.argument<String>("phone")
                if (phoneNumber != null) {
                    makeCall(phoneNumber)
                    result.success("Llamada iniciada")
                } else {
                    result.error("INVALID_NUMBER", "Número no válido", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Canal para traer la app al frente (existente)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "bringToForeground") {
                bringToForeground()
                result.success("App traída al frente")
            } else {
                result.notImplemented()
            }
        }
        
        // Canal para notificaciones (existente)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showBleDisconnectedNotification" -> {
                    showBleDisconnectedNotification()
                    result.success(true)
                }
                "showBleConnectedNotification" -> {
                    showBleConnectedNotification()
                    result.success(true)
                }
                "showLocationConfirmedNotification" -> {
                    showLocationConfirmedNotification()
                    result.success(true)
                }
                "showLocationFailedNotification" -> {
                    showLocationFailedNotification()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIFECYCLE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "forceStopAllServices" -> {
                    forceStopAllServicesNuclear()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // Funciones existentes sin cambios
    private fun makeCall(phoneNumber: String) {
        val intent = Intent(Intent.ACTION_CALL)
        intent.data = Uri.parse("tel:$phoneNumber")

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
            startActivity(intent)
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CALL_PHONE), 1)
        }
    }

    private fun bringToForeground() {
        val notificationIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "BleSOSApp::WakeLockTag"
            )
            wakeLock.acquire(10000)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error al adquirir wakelock: ${e.message}")
        }

        val notification = NotificationCompat.Builder(this, "SOS_ALERT_CHANNEL")
            .setContentTitle("🚨 ALERTA SOS ACTIVADA")
            .setContentText("¡SE HA PRESIONADO EL BOTÓN DE PÁNICO!")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cerrar Alerta",
                PendingIntent.getActivity(
                    this, 1, notificationIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(911, notification)

        try {
            startActivity(notificationIntent)
            Log.d("MainActivity", "Actividad lanzada directamente")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error al lanzar actividad: ${e.message}")
        }

        Log.d("MainActivity", "🚨 Notificación SOS mostrada (ahora es borrable)")
    }

    private fun showFullScreenNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val fullScreenIntent = Intent(this, MainActivity::class.java)
        val fullScreenPendingIntent = PendingIntent.getActivity(this, 0, fullScreenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val notification = NotificationCompat.Builder(this, "SOS_ALERT_CHANNEL")
            .setContentTitle("🚨 Alerta SOS Activada")
            .setContentText("Se ha presionado el botón de pánico")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(SOS_NOTIFICATION_ID, notification)
    }

    private fun showBleDisconnectedNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "BLE_STATUS_CHANNEL")
            .setContentTitle("Conexión BLE Perdida")
            .setContentText("Se ha perdido la conexión con el dispositivo BLE.")
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(BLE_DISCONNECTED_NOTIFICATION_ID, notification)

        Log.d("MainActivity", "🔴 Notificación de desconexión BLE mostrada")
    }

    private fun showBleConnectedNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "BLE_STATUS_CHANNEL")
            .setContentTitle("Conexión BLE Establecida")
            .setContentText("Conectado al dispositivo BLE correctamente.")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(BLE_CONNECTED_NOTIFICATION_ID, notification)

        Log.d("MainActivity", "🟢 Notificación de conexión BLE mostrada")
    }

    private fun showLocationConfirmedNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "LOCATION_STATUS_CHANNEL")
            .setContentTitle("Ubicación Confirmada")
            .setContentText("El servidor confirmó la recepción de tu ubicación.")
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(LOCATION_CONFIRMED_NOTIFICATION_ID, notification)

        Log.d("MainActivity", "🟢 Notificación de ubicación confirmada mostrada")
    }

    private fun showLocationFailedNotification() {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "LOCATION_STATUS_CHANNEL")
            .setContentTitle("Envío de Ubicación Fallido")
            .setContentText("No se pudo confirmar el envío al servidor.")
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setAutoCancel(true)
            .setOngoing(false)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(LOCATION_FAILED_NOTIFICATION_ID, notification)

        Log.d("MainActivity", "🔴 Notificación de fallo de ubicación mostrada")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ✅ AGREGAR: Solicitar todas las exenciones críticas
        requestAllCriticalExemptions()

        // Crear canales de notificación
        val sosChannel = NotificationChannel(
            "SOS_ALERT_CHANNEL",
            "Alerta SOS",
            NotificationManager.IMPORTANCE_HIGH
        )
        sosChannel.enableLights(true)
        sosChannel.lightColor = Color.RED
        sosChannel.enableVibration(true)
        
        val bleStatusChannel = NotificationChannel(
            "BLE_STATUS_CHANNEL",
            "Estado BLE",
            NotificationManager.IMPORTANCE_HIGH
        )
        bleStatusChannel.description = "Notificaciones de estado de conexión BLE"
        bleStatusChannel.enableLights(true)
        bleStatusChannel.lightColor = Color.BLUE
        bleStatusChannel.enableVibration(true)
        bleStatusChannel.setBypassDnd(false)
        bleStatusChannel.setShowBadge(true)
        
        val locationStatusChannel = NotificationChannel(
            "LOCATION_STATUS_CHANNEL",
            "Estado de Ubicación",
            NotificationManager.IMPORTANCE_HIGH
        )
        locationStatusChannel.description = "Notificaciones de estado de envío de ubicación"
        locationStatusChannel.enableLights(true)
        locationStatusChannel.lightColor = Color.GREEN
        locationStatusChannel.enableVibration(true)
        locationStatusChannel.setBypassDnd(false)
        locationStatusChannel.setShowBadge(true)
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(sosChannel)
        notificationManager.createNotificationChannel(bleStatusChannel)
        notificationManager.createNotificationChannel(locationStatusChannel)
    }

    // ✅ NUEVO MÉTODO: Solicitar todas las exenciones
    private fun requestAllCriticalExemptions() {
        try {
            Log.d("MainActivity", "🔋 Solicitando exenciones críticas para supervivencia...")
            
            // 1. Battery Optimization Exemption
            requestBatteryOptimizationExemption()
            
            // 2. Data Saver Exemption  
            requestDataSaverExemption()
            
            // 3. Background App Refresh
            // requestBackgroundAppPermission()   ESTO REGRESAR SI FALLA SIN MOSTRAR PERMISOS
            
            Log.d("MainActivity", "✅ Exenciones solicitadas correctamente")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error solicitando exenciones: ${e.message}")
        }
    }

    // Battery Optimization
    private fun requestBatteryOptimizationExemption() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                Log.d("MainActivity", "🔋 Solicitando exención de optimización de batería")
            } else {
                Log.d("MainActivity", "✅ Ya tenemos exención de batería")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error en battery optimization: ${e.message}")
        }
    }

    // Data Saver Exemption
    private fun requestDataSaverExemption() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                val intent = Intent(Settings.ACTION_IGNORE_BACKGROUND_DATA_RESTRICTIONS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                Log.d("MainActivity", "📡 Solicitando exención de data saver")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error en data saver: ${e.message}")
        }
    }

    // Background App Permission
    private fun requestBackgroundAppPermission() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            Log.d("MainActivity", "📱 Abriendo configuración de la app")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error abriendo configuración: ${e.message}")
        }
    }

    // ✅ MÉTODO onDestroy() - Esta es la parte crítica
    override fun onDestroy() {
        Log.d("MainActivity", "🛑 MainActivity.onDestroy() - INICIO")
        
        // ✅ MARCAR que la app se está cerrando permanentemente
        appIsClosingPermanently = true
        
        // ✅ ENVIAR SEÑAL A FLUTTER antes de que se desconecte
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, LIFECYCLE_CHANNEL).invokeMethod(
                    "appClosingPermanently", 
                    mapOf("timestamp" to System.currentTimeMillis())
                )
            }
            Log.d("MainActivity", "✅ Señal enviada a Flutter")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error enviando señal a Flutter: ${e.message}")
        }
        
        // ✅ ESPERAR un momento para que Flutter procese
        try {
            Thread.sleep(500) // 500ms para que Flutter reciba y procese
        } catch (e: InterruptedException) {
            Log.w("MainActivity", "Sleep interrumpido")
        }
        
        // ✅ DETENER TODOS LOS SERVICIOS AGRESIVAMENTE
        stopAllForegroundServices()
        
        // ✅ LIMPIAR TODAS LAS NOTIFICACIONES
        clearAllNotifications()
        
        super.onDestroy()
        Log.d("MainActivity", "🏁 MainActivity.onDestroy() - COMPLETADO")
    }
    
    // ✅ MÉTODO para detener servicios agresivamente
    private fun stopAllForegroundServices() {
        try {
            Log.d("MainActivity", "🛑 Deteniendo TODOS los servicios...")
            
            // Método 1: Detener por Intent directo
            val serviceIntent = Intent(this, Class.forName("com.pravera.flutter_foreground_task.service.ForegroundService"))
            serviceIntent.putExtra("FORCE_STOP", true)
            serviceIntent.putExtra("STOP_PERMANENTLY", true)
            serviceIntent.putExtra("APP_CLOSING", true)
            stopService(serviceIntent)
            
            // Método 2: Detener por ComponentName
            val componentName = ComponentName(
                "com.miempresa.ble_sos_ap",
                "com.pravera.flutter_foreground_task.service.ForegroundService"
            )
            val stopIntent = Intent().apply {
                component = componentName
                putExtra("FORCE_STOP", true)
            }
            stopService(stopIntent)
            
            // Método 3: Forzar detención de cualquier servicio con nuestro packageName
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningServices = activityManager.getRunningServices(Integer.MAX_VALUE)
            
            for (service in runningServices) {
                if (service.service.packageName == packageName) {
                    Log.d("MainActivity", "🎯 Encontrado servicio: ${service.service.className}")
                    val forceStopIntent = Intent().apply {
                        component = service.service
                        putExtra("FORCE_STOP", true)
                    }
                    stopService(forceStopIntent)
                }
            }
            
            Log.d("MainActivity", "✅ Servicios detenidos con múltiples métodos")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error deteniendo servicios: ${e.message}")
        }
    }
    
    // ✅ MÉTODO para limpiar notificaciones
    private fun clearAllNotifications() {
        try {
            val notificationManager = getSystemService(NotificationManager::class.java)
            
            // Cancelar notificaciones específicas
            notificationManager.cancel(SOS_NOTIFICATION_ID)
            notificationManager.cancel(BLE_DISCONNECTED_NOTIFICATION_ID)
            notificationManager.cancel(BLE_CONNECTED_NOTIFICATION_ID)
            notificationManager.cancel(LOCATION_CONFIRMED_NOTIFICATION_ID)
            notificationManager.cancel(LOCATION_FAILED_NOTIFICATION_ID)
            
            // Cancelar notificación del servicio persistente (IDs comunes de flutter_foreground_task)
            notificationManager.cancel(1000) // ID típico de flutter_foreground_task
            notificationManager.cancel(1001) // Backup ID
            notificationManager.cancel(2000) // Otro ID posible
            
            // Cancelar TODAS las notificaciones como medida final
            notificationManager.cancelAll()
            
            Log.d("MainActivity", "✅ TODAS las notificaciones eliminadas")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error eliminando notificaciones: ${e.message}")
        }
    }
    
    override fun onPause() {
        super.onPause()
        // NO hacer nada aquí - solo cuando realmente se cierre la app
    }
    
    override fun onStop() {
        super.onStop()
        // NO hacer nada aquí - solo cuando realmente se cierre la app
    }

    private fun forceStopAllServicesNuclear() {
        Log.d("MainActivity", "🔥 === DETENCIÓN NUCLEAR NATIVA ===")
        
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            
            // Obtener TODOS los servicios ejecutándose
            val runningServices = activityManager.getRunningServices(Integer.MAX_VALUE)
            
            Log.d("MainActivity", "🔍 Servicios ejecutándose: ${runningServices.size}")
            
            // Detener CUALQUIER servicio de nuestro package
            for (service in runningServices) {
                if (service.service.packageName == packageName) {
                    Log.d("MainActivity", "🎯 DETENIENDO NUCLEAR: ${service.service.className}")
                    
                    // Método 1: stopService directo
                    val stopIntent = Intent().apply {
                        component = service.service
                        putExtra("NUCLEAR_STOP", true)
                        putExtra("FORCE_STOP", true)
                        putExtra("PERMANENT_STOP", true)
                    }
                    stopService(stopIntent)
                    
                    // Método 2: killBackgroundProcesses (más agresivo)
                    try {
                        activityManager.killBackgroundProcesses(service.service.packageName)
                        Log.d("MainActivity", "💀 killBackgroundProcesses ejecutado para ${service.service.packageName}")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "❌ Error en killBackgroundProcesses: ${e.message}")
                    }
                }
            }
            
            // Método 3: Detener por nombres específicos conocidos
            val knownServiceNames = listOf(
                "com.pravera.flutter_foreground_task.service.ForegroundService",
                "FlutterForegroundService",
                "ForegroundTaskService"
            )
            
            for (serviceName in knownServiceNames) {
                try {
                    val intent = Intent().apply {
                        setClassName(packageName, serviceName)
                        putExtra("NUCLEAR_STOP", true)
                    }
                    stopService(intent)
                    Log.d("MainActivity", "🎯 Intento detener servicio específico: $serviceName")
                } catch (e: Exception) {
                    Log.d("MainActivity", "ℹ️ Servicio $serviceName no encontrado o ya detenido")
                }
            }
            
            // Método 4: Limpiar notificaciones AGRESIVAMENTE
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.cancelAll()
            
            // También cancelar por IDs específicos conocidos de flutter_foreground_task
            for (id in 1000..1010) {
                notificationManager.cancel(id)
            }
            
            Log.d("MainActivity", "✅ DETENCIÓN NUCLEAR NATIVA COMPLETADA")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error en detención nuclear nativa: ${e.message}")
        }
    }
}