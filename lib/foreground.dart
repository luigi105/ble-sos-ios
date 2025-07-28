import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_data.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'coms.dart';
import 'package:flutter/services.dart';

// Función que se ejecuta en el aislamiento del servicio en primer plano
@pragma('vm:entry-point')
void startCallback() {
  // El aislamiento que ejecuta el servicio en primer plano
  FlutterForegroundTask.setTaskHandler(BleReconnectionTaskHandler());
}

// Manejador de tareas para el servicio en primer plano
class BleReconnectionTaskHandler extends TaskHandler {
  Timer? _timer;
  SendPort? _sendPort;
  static SendPort? _staticSendPort;
  
 @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    _staticSendPort = sendPort; // Guardar en variable estática
    
    // Iniciar un timer para verificar la conexión periódicamente
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndReconnect();
    });
    return;
  }

   static void sendMessage(String message) {
    if (_staticSendPort != null) {
      _staticSendPort!.send(message);
    }
  }
  
  void _checkAndReconnect() async {
    // Solo enviamos un mensaje para que la app principal intente reconectar
    if (_sendPort != null) {
      _sendPort!.send('RECONNECT');
    }
  }
  
    @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    _timer?.cancel();
    return;
  }
  
  // Añadimos este método que faltaba
  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // No hacemos nada aquí para evitar actualizaciones constantes de la notificación
    return;
  }
}

class ForegroundService {
  static bool isRunning = false;
  static Timer? reconnectionTimer;
  static Timer? checkConnectionTimer;
  static ReceivePort? _receivePort;
  static Function? locationServiceCallback;
  
  static Future<void> initForegroundTask() async {
    // Configurar el servicio en primer plano con notificación mínima
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ble_sos_service',
        channelName: 'BLE SOS Service',
        channelDescription: 'Servicio de conexión BLE',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    
    // Iniciar el servicio con una notificación básica
    bool serviceStarted = await FlutterForegroundTask.startService(
      notificationTitle: 'BLE SOS Service',
      notificationText: 'Servicio activo',
      callback: startCallback,
    );
    
    if (serviceStarted) {
      _receivePort = FlutterForegroundTask.receivePort;
      _listenToBackgroundMessages();
    }
  }
  
   
  static void _listenToBackgroundMessages() {
    _receivePort?.listen((message) {
      if (message == 'RECONNECT') {
        // Recibimos mensaje del servicio en primer plano para intentar reconectar
        attemptReconnection();
      } else if (message == 'SEND_LOCATION') {
        // Ejecutar el callback si está registrado
        if (locationServiceCallback != null) {
          locationServiceCallback!();
        }
      }
    });
  }


// Método para registrar el callback
static void registerLocationServiceCallback(Function callback) {
  locationServiceCallback = callback;
}


// ✅ REEMPLAZAR startForegroundTask() en foreground.dart para prevenir auto-restart

static Future<void> startForegroundTask() async {
  if (isRunning) return;
  
  print("🚀 Iniciando servicio ULTRA-AGRESIVO para supervivencia...");
  
  // ✅ CONFIGURACIÓN ULTRA-AGRESIVA
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'ble_sos_critical_survival', 
      channelName: '🚨 Servicio Crítico SOS',
      channelDescription: 'SERVICIO DE EMERGENCIA - NO DESACTIVAR - Requerido para funcionamiento 24/7',
      channelImportance: NotificationChannelImportance.MAX, // ✅ MÁXIMA prioridad
      priority: NotificationPriority.MAX,                   // ✅ MÁXIMA prioridad
      enableVibration: false,
      playSound: false,
      isSticky: true,        // ✅ CRÍTICO: Notificación pegajosa
      showWhen: true,        // ✅ Mostrar timestamp
      visibility: NotificationVisibility.VISIBILITY_PUBLIC, // ✅ Siempre visible
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
      buttons: [
        // ✅ Botón para mantener activo
        const NotificationButton(
          id: 'keep_alive', 
          text: '🔥 Mantener Activo'
        ),
        const NotificationButton(
          id: 'status_check', 
          text: '📊 Ver Estado'
        ),
      ],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 15000,          // ✅ REDUCIDO: 15 segundos (más agresivo)
      isOnceEvent: false,
      autoRunOnBoot: true,      // ✅ ACTIVADO: Auto-iniciar en boot
      allowWakeLock: true,      // ✅ MANTENER: Wake lock
      allowWifiLock: true,      // ✅ MANTENER: WiFi lock
    ),
  );
  
  String notificationTitle = BleData.conBoton == 1 
    ? '🚨 BLE SOS - Servicio Crítico Activo' 
    : '🚨 SOS Ubicación - Servicio Crítico Activo';
    
  String notificationText = BleData.conBoton == 1
    ? '🔵 BLE Conectado | 📡 Ubicación Activa | 🔋 Monitoreando'
    : '📡 Ubicación GPS Activa | 🚨 Sistema SOS Operativo';
  
  bool serviceStarted = await FlutterForegroundTask.startService(
    notificationTitle: notificationTitle,
    notificationText: notificationText,
    callback: startCallback,
  );
  
  if (serviceStarted) {
    _receivePort = FlutterForegroundTask.receivePort;
    _listenToBackgroundMessages();
    print("✅ Servicio ULTRA-AGRESIVO iniciado: $notificationTitle");
  } else {
    print("❌ Error al iniciar servicio ULTRA-AGRESIVO");
  }
  
  isRunning = true;
  startConnectionMonitoring();
}

// ✅ REEMPLAZAR stopForegroundTask() - VERSIÓN NUCLEAR
static void stopForegroundTask() async {
  print("🛑 === INICIANDO DETENCIÓN NUCLEAR ===");
  
  // ✅ MARCAR como detenido ANTES de cualquier cosa
  isRunning = false;
  
  // ✅ CANCELAR ABSOLUTAMENTE TODO
  try {
    reconnectionTimer?.cancel();
    reconnectionTimer = null;
    checkConnectionTimer?.cancel();
    checkConnectionTimer = null;
    _receivePort?.close();
    _receivePort = null;
    locationServiceCallback = null;
    print("✅ Todos los recursos internos cancelados");
  } catch (e) {
    print("❌ Error cancelando recursos: $e");
  }
  
  // ✅ DETENCIÓN AGRESIVA CON MÚLTIPLES MÉTODOS
  try {
    for (int attempt = 1; attempt <= 10; attempt++) { // ✅ Aumentar a 10 intentos
      print("🔄 INTENTO NUCLEAR $attempt/10...");
      
      // Verificar estado actual
      bool serviceRunning = await FlutterForegroundTask.isRunningService;
      print("🔍 ¿Servicio ejecutándose?: $serviceRunning");
      
      if (!serviceRunning) {
        print("✅ SERVICIO DETENIDO en intento $attempt");
        break;
      }
      
      // ✅ MÉTODO 1: stopService normal
      try {
        bool stopped = await FlutterForegroundTask.stopService();
        print("🔄 stopService() resultado: $stopped");
      } catch (e) {
        print("❌ Error en stopService(): $e");
      }
      
      // ✅ MÉTODO 2: Intentar detener usando plataforma nativa si es intento > 5
      if (attempt > 5) {
        try {
          print("🔥 MÉTODO NUCLEAR: Forzando detención nativa...");
          
          // Usar MethodChannel para enviar orden de detención nativa
          const MethodChannel('com.miempresa.ble_sos_ap/lifecycle')
              .invokeMethod('forceStopAllServices');
          
        } catch (e) {
          print("❌ Error en detención nativa: $e");
        }
      }
      
      // Esperar progresivamente más tiempo
      int waitTime = attempt * 300; // 300ms, 600ms, 900ms, etc.
      await Future.delayed(Duration(milliseconds: waitTime));
      
      // Verificar resultado final
      bool stillRunning = await FlutterForegroundTask.isRunningService;
      if (!stillRunning) {
        print("✅ SERVICIO FINALMENTE DETENIDO en intento $attempt");
        break;
      }
      
      if (attempt == 10) {
        print("🚨 ADVERTENCIA CRÍTICA: Servicio SIGUE ejecutándose después de 10 intentos nucleares");
        print("🚨 Esto podría requerir reinicio del dispositivo o intervención manual");
      }
    }
    
  } catch (e) {
    print("❌ Error durante detención nuclear: $e");
  }
  
  print("🛑 === DETENCIÓN NUCLEAR COMPLETADA ===");
}


// Añadir este método nuevo para verificar si el servicio realmente está ejecutándose:

static Future<bool> isServiceRunning() async {
  try {
    return await FlutterForegroundTask.isRunningService;
  } catch (e) {
    print("Error al verificar estado del servicio: $e");
    return false;
  }
}


static Future<void> forceStopAllServices() async {
  print("🚨 Forzando detención de todos los servicios...");
  
  try {
    // Detener cualquier servicio ejecutándose
    await FlutterForegroundTask.stopService();
    
    // Esperar un momento
    await Future.delayed(Duration(milliseconds: 500));
    
    // Verificar si sigue ejecutándose
    bool stillRunning = await FlutterForegroundTask.isRunningService;
    if (stillRunning) {
      print("⚠️ Servicio sigue activo, intentando detención adicional...");
      await FlutterForegroundTask.stopService();
    }
    
    // Limpiar todas las variables
    reconnectionTimer?.cancel();
    checkConnectionTimer?.cancel();
    _receivePort?.close();
    _receivePort = null;
    locationServiceCallback = null;
    isRunning = false;
    
    print("✅ Limpieza forzada completada");
  } catch (e) {
    print("❌ Error durante limpieza forzada: $e");
  }
}

  
  // Iniciar un monitor de conexión que funcione incluso en modo Doze
 static void startConnectionMonitoring() {
  checkConnectionTimer?.cancel();
  
  print("🚀 Iniciando monitoreo ULTRA-AGRESIVO...");
  
  // ✅ MONITOREO MÁS FRECUENTE - 15 segundos
  if (BleData.conBoton == 1) {
    checkConnectionTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      print("🔍 [ULTRA] Verificando BLE cada 15s...");
      if (!BleData.isConnected) {
        print("🔄 [ULTRA] Detectada desconexión BLE - Reconectando...");
        attemptReconnection();
      } else {
        print("✅ [ULTRA] BLE conectado OK");
      }
    });
  } else {
    // Para conBoton == 2, verificar internet cada 20 segundos
    checkConnectionTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      print("🔍 [ULTRA] Verificando internet cada 20s...");
      
      try {
        bool hasInternet = await checkInternetConnection();
        if (hasInternet) {
          print("📡 [ULTRA] Internet OK - Enviando ubicación...");
          sendLocationFromService();
        } else {
          print("⚠️ [ULTRA] Sin internet detectado");
        }
      } catch (e) {
        print("❌ [ULTRA] Error verificando internet: $e");
      }
    });
  }
  
  print("✅ Monitoreo ULTRA-AGRESIVO configurado");
}


static Future<bool> checkInternetConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print("Error al verificar conectividad: $e");
      return false;
    }
  }

// Método para solicitar el envío de ubicación desde el servicio
  static void sendLocationFromService() {
    if (locationServiceCallback != null) {
      locationServiceCallback!();
    }
  }
  
  static Future<void> attemptReconnection() async {
  // Si conBoton != 1, no intentar reconectar
  if (BleData.conBoton != 1) return;
  
  // Verificar primero si ya estamos conectados
  if (BleData.isConnected) {
    print("✅ Ya estamos conectados, no es necesario intentar reconexión");
    return;
  }
  
  // Verificar si necesitamos incrementar el contador en el servicio en primer plano
  BleData.reconnectionAttemptCount++;
  print("🔄 [Servicio] Intentando reconectar BLE... Intento #${BleData.reconnectionAttemptCount}/${BleData.maxReconnectionAttemptsBeforeNotification}");
  
  // Si alcanzamos el umbral, mostrar notificación (si está permitido)
  if (BleData.reconnectionAttemptCount == BleData.maxReconnectionAttemptsBeforeNotification && 
      BleData.bleNotificationsEnabled) {
    print("📱 [Servicio] NOTIFICACIÓN DE DESCONEXIÓN BLE - Intento #${BleData.reconnectionAttemptCount}");
    
    // Configurar la bandera ANTES de mostrar la notificación
    BleData.bleDisconnectionNotificationShown = true;
    BleData.markDisconnectionNotificationShown();
    print("🔔 [Servicio] Bandera bleDisconnectionNotificationShown configurada a true");
    
    // Usar el handler de la app principal para mostrar la notificación
    CommunicationService().showBleDisconnectedNotification();
  }
  
   try {
    // Verificar estado del adaptador Bluetooth
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      print("⚠️ Bluetooth apagado, no se puede reconectar");
      try {
        await FlutterBluePlus.turnOn();
        // Esperar a que se encienda
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print("❌ No se pudo activar Bluetooth: $e");
        return;
      }
    }
    
    // Verificar si ya está reconectado (puede haber cambiado mientras tanto)
    List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
    for (var device in connectedDevices) {
      if (device.remoteId.toString() == BleData.macAddress) {
        print("✅ Dispositivo ya conectado: ${device.remoteId}");
        BleData.update(
          newMacAddress: device.remoteId.toString(),
          connectionStatus: true,
        );
        BleData.reconnectionAttemptCount = 0;
        BleData.bleDisconnectionNotificationShown = false;  // Resetear el flag cuando la conexión se restablece
        print("✅ Reconexión exitosa. Contador reiniciado: 0");
        return;
      }
    }
    
    // Buscar el dispositivo guardado
    print("🔍 Buscando dispositivo: ${BleData.macAddress}");
    
    // Detener cualquier escaneo anterior
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("Advertencia al detener escaneo: $e");
    }
    
    // Comenzar nuevo escaneo
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    
    // Escuchar resultados del escaneo
    StreamSubscription? scanSubscription;
    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (result.device.remoteId.toString() == BleData.macAddress) {
          FlutterBluePlus.stopScan();
          scanSubscription?.cancel();
          
          // Intentar conectar
          result.device.connect(timeout: const Duration(seconds: 30)).then((_) {
            print("✅ Reconexión exitosa desde servicio en primer plano");
            BleData.update(
              newMacAddress: result.device.remoteId.toString(),
              connectionStatus: true,
            );
            
            // Reiniciar contador al conectar exitosamente
            BleData.reconnectionAttemptCount = 0;
            BleData.bleDisconnectionNotificationShown = false;  // Resetear el flag cuando la conexión se restablece
            print("✅ Contador de intentos de reconexión reiniciado: 0");
            
            // Descubrir servicios
            result.device.discoverServices();
          }).catchError((e) {
            print("❌ Error en reconexión desde servicio: $e");
            BleData.update(connectionStatus: false);
          });
        }
      }
    });
    
    // Asegurarnos de detener el escaneo después de un tiempo
    Future.delayed(const Duration(seconds: 8), () {
      try {
        FlutterBluePlus.stopScan();
      } catch (e) {
        print("Error al detener escaneo en timeout: $e");
      }
      scanSubscription?.cancel();
    });
    
  } catch (e) {
    print("Error en attemptReconnection: $e");
  }
}
}