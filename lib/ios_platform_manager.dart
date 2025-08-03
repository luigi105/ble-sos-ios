// ============================================================================
// ARCHIVO: ios_platform_manager.dart - VERSIÓN CORREGIDA CON IMPORTS
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // ✅ IMPORT CRÍTICO
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_data.dart';
import 'coms.dart';
import 'package:audioplayers/audioplayers.dart';


class IOSPlatformManager {
  static bool _isInitialized = false;
  static StreamSubscription<Position>? _locationSubscription;
  static FlutterLocalNotificationsPlugin? _localNotifications;
  static DateTime? _lastLocationSent;
  static const Duration _minimumLocationInterval = Duration(minutes: 5);
  
  // ✅ INICIALIZACIÓN ESPECÍFICA PARA iOS
  static Future<void> initialize() async {
    if (_isInitialized || !Platform.isIOS) return;
    
    print("🍎 Inicializando iOS Platform Manager...");
    
    try {
      // 1. Configurar notificaciones locales
      await _setupLocalNotifications();
      
      // 2. Configurar seguimiento de ubicación significativa
      await _setupSignificantLocationChanges();
      
      // 3. Configurar manejo de ciclo de vida de la app
      _setupAppLifecycleHandling();
      
      _isInitialized = true;
      print("✅ iOS Platform Manager inicializado exitosamente");
      
    } catch (e) {
      print("❌ Error inicializando iOS Platform Manager: $e");
    }
  }
  
  // ✅ CONFIGURAR NOTIFICACIONES LOCALES
  static Future<void> _setupLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    
    // ✅ CONFIGURACIÓN ESPECÍFICA iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // Para emergencias críticas
    );
    
    const InitializationSettings settings = InitializationSettings(
      iOS: iosSettings,
    );
    
    await _localNotifications!.initialize(settings);
    
    // Solicitar permisos explícitamente para iOS
    await _localNotifications!
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true, // Para alertas de emergencia
        );
    
    print("✅ Notificaciones locales iOS configuradas");
  }
  
  // ✅ CONFIGURAR CAMBIOS SIGNIFICATIVOS DE UBICACIÓN
static Future<void> _setupSignificantLocationChanges() async {
  print("📍 Configurando seguimiento de ubicación cada 100m para iOS...");
  
  // Verificar permisos
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    print("❌ Permisos de ubicación no otorgados para iOS");
    return;
  }
  
  // ✅ CONFIGURACIÓN PARA 100 METROS (tu geofence de 200m)
  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high, // ✅ Alta precisión para geofence de 200m
    distanceFilter: 100, // ✅ iOS enviará actualización cada 100+ metros
    timeLimit: Duration(minutes: 5), // ✅ Timeout si no hay cambios
  );
  
  _locationSubscription = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen(
    _handleSignificantLocationChange,
    onError: (error) {
      print("❌ Error en stream de ubicación iOS: $error");
    },
  );
  
  print("✅ iOS configurado para enviar ubicación cada 100+ metros");
}
  
  // ✅ MANEJAR CAMBIO SIGNIFICATIVO DE UBICACIÓN
  static Future<void> _handleSignificantLocationChange(Position position) async {
    print("📍 Cambio significativo de ubicación detectado en iOS:");
    print("   Lat: ${position.latitude}, Lng: ${position.longitude}");
    print("   Precisión: ${position.accuracy}m");
    
    // Evitar envíos demasiado frecuentes
    DateTime now = DateTime.now();
    if (_lastLocationSent != null) {
      Duration timeSinceLastSent = now.difference(_lastLocationSent!);
      if (timeSinceLastSent < _minimumLocationInterval) {
        print("⏳ Ubicación muy reciente, esperando ${_minimumLocationInterval.inMinutes - timeSinceLastSent.inMinutes} minutos más");
        return;
      }
    }
    
    try {
      // Enviar ubicación al servidor usando el servicio existente
      await _sendLocationToServer(position);
      _lastLocationSent = now;
      
      // Actualizar estado de confirmación de ubicación
      BleData.setLocationConfirmed(true);
      
    } catch (e) {
      print("❌ Error enviando ubicación desde iOS: $e");
      BleData.setLocationConfirmed(false);
    }
  }
  
  // ✅ ENVIAR UBICACIÓN AL SERVIDOR (iOS)
  static Future<void> _sendLocationToServer(Position position) async {
    try {
      String northSouth = position.latitude >= 0 ? "North" : "South";
      String eastWest = position.longitude >= 0 ? "East" : "West";
      String bleMacAddress = BleData.conBoton == 2 ? "N/A" : BleData.macAddress;
      String activo = BleData.conBoton == 2 ? "0" : (BleData.isConnected ? "1" : "0");
      int batteryLevel = BleData.conBoton == 2 ? 0 : BleData.batteryLevel;
      
      final response = await CommunicationService().sendLocation(
        BleData.imei,
        position.latitude.abs(),
        position.longitude.abs(),
        northSouth,
        eastWest,
        bleMacAddress,
        activo,
        batteryLevel,
        "1", // cellOnline
      );
      
      if (response.statusCode == 200) {
        print("✅ Ubicación iOS enviada exitosamente");
      } else {
        throw Exception("Error HTTP: ${response.statusCode}");
      }
      
    } catch (e) {
      print("❌ Error enviando ubicación iOS: $e");
      throw e;
    }
  }
  
  // ✅ CONFIGURAR BLE PARA iOS (Auto-reconnect)
  static Future<void> setupiOSBLE(BluetoothDevice device) async {
    print("🔵 Configurando BLE específico para iOS...");
    
    try {
      // Conectar con autoConnect habilitado (crítico para iOS)
      await device.connect(
        autoConnect: true, // iOS manejará reconexión automáticamente
        timeout: const Duration(seconds: 30),
      );
      
      // Configurar listener permanente para estado de conexión
      device.connectionState.listen((state) {
        print("🔵 Estado BLE iOS: $state");
        
        if (state == BluetoothConnectionState.connected) {
          print("✅ BLE conectado en iOS - Configurando notificaciones...");
          _setupBLENotifications(device);
          BleData.update(connectionStatus: true);
        } else {
          print("⚠️ BLE desconectado en iOS - iOS intentará reconectar automáticamente");
          BleData.update(connectionStatus: false);
        }
      });
      
      print("✅ BLE iOS configurado con auto-reconnect");
      
    } catch (e) {
      print("❌ Error configurando BLE iOS: $e");
      throw e;
    }
  }
  
  // ✅ CONFIGURAR NOTIFICACIONES BLE
  static Future<void> _setupBLENotifications(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e') {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              
              // ✅ CRITICAL: Este listener funcionará incluso desde background en iOS
              characteristic.value.listen((value) {
                if (value.isNotEmpty && value.length >= 5) {
                  print("🔵 Datos BLE recibidos en iOS: $value");
                  
                  // Detectar botón SOS presionado
                  if (value[4] == 1) {
                    print("🚨 BOTÓN SOS PRESIONADO EN iOS!");
                    _handleEmergencyIOS();
                  }
                }
              });
              
              print("✅ Notificaciones BLE configuradas para iOS");
            }
          }
        }
      }
    } catch (e) {
      print("❌ Error configurando notificaciones BLE: $e");
    }
  }
  
  // ✅ MANEJAR EMERGENCIA EN iOS (30 segundos disponibles)
static Future<void> _handleEmergencyIOS() async {
  print("🚨 === MANEJO DE EMERGENCIA iOS - 30 segundos disponibles ===");
  
  try {
    // 1. REPRODUCIR SONIDO SOS INMEDIATAMENTE
    print("🔊 Reproduciendo sonido SOS...");
    await playSosAudioBackground();
    
    // 2. Obtener ubicación rápidamente (5-8 segundos)
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8)); // ✅ Reducido para dar más tiempo al audio
      print("📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("⚠️ Error obteniendo ubicación: $e");
    }
    
    // 3. Enviar alerta SOS al servidor (5-8 segundos)
    try {
      await CommunicationService().sendSosAlert(BleData.macAddress);
      print("✅ Alerta SOS enviada al servidor");
      
      if (position != null) {
        await _sendLocationToServer(position);
        print("✅ Ubicación de emergencia enviada");
      }
    } catch (e) {
      print("⚠️ Error enviando alerta: $e");
    }
    
    // 4. Mostrar notificación crítica adicional
    await showCriticalBleNotification(
      "🚨 SOS ACTIVADO", 
      "Alerta enviada desde dispositivo BLE. Ubicación transmitida.",
    );
    
    // 5. Hacer llamada telefónica automática
    if (BleData.autoCall && BleData.sosNumber != "UNKNOWN_SOS") {
      try {
        final Uri phoneUri = Uri.parse("tel://${BleData.sosNumber}");
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
          print("📞 Llamada SOS iniciada a ${BleData.sosNumber}");
        }
      } catch (e) {
        print("⚠️ Error iniciando llamada: $e");
      }
    }
    
    print("✅ Emergencia iOS procesada con audio SOS");
    
  } catch (e) {
    print("❌ Error crítico procesando emergencia iOS: $e");
    
    // Fallback: Al menos reproducir sonido de emergencia
    await playSosAudioBackground();
  }
  
  print("🚨 === FIN MANEJO DE EMERGENCIA iOS ===");
}
  
  // ✅ MOSTRAR NOTIFICACIÓN DE EMERGENCIA
  static Future<void> showEmergencyNotification({bool isError = false}) async {
    if (_localNotifications == null) return;
    
    try {
      // ✅ CONFIGURACIÓN ACTUALIZADA PARA NUEVAS VERSIONES
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical, // Crítico para emergencias
        categoryIdentifier: 'SOS_EMERGENCY',
      );
      
      const NotificationDetails details = NotificationDetails(iOS: iosDetails);
      
      String title = isError ? "🚨 SOS - Error" : "🚨 ALERTA SOS ACTIVADA";
      String body = isError 
          ? "Error enviando alerta. Contacte manualmente." 
          : "Alerta de emergencia enviada. Ubicación: ${DateTime.now().toString().substring(11, 16)}";
      
      await _localNotifications!.show(
        999, // ID único para emergencias
        title,
        body,
        details,
      );
      
      print("✅ Notificación de emergencia mostrada");
      
    } catch (e) {
      print("❌ Error mostrando notificación de emergencia: $e");
    }
  }
  
  // ✅ CONFIGURAR MANEJO DE CICLO DE VIDA
  static void _setupAppLifecycleHandling() {
    // En iOS, no necesitamos manejo complejo de ciclo de vida
    // iOS mantendrá BLE y ubicación funcionando automáticamente
    print("✅ Ciclo de vida iOS configurado (manejo automático)");
  }

  static Future<void> setupBLEDevice(BluetoothDevice device) async {
  print("🔵 Configurando dispositivo BLE específico para iOS...");
  
  try {
    // ✅ CONEXIÓN con autoConnect habilitado
    await device.connect(
      autoConnect: true, // iOS manejará reconexión automáticamente
      timeout: const Duration(seconds: 30),
    );
    
    // ✅ CONFIGURAR listener permanente para estado de conexión
    device.connectionState.listen((state) {
      print("🔵 Estado BLE iOS: $state");
      
      if (state == BluetoothConnectionState.connected) {
        print("✅ BLE conectado en iOS");
        BleData.update(connectionStatus: true);
        _setupBLENotifications(device); // Configurar notificaciones
      } else {
        print("⚠️ BLE desconectado en iOS - iOS intentará reconectar automáticamente");
        BleData.update(connectionStatus: false);
      }
    });
    
    print("✅ BLE iOS configurado con auto-reconnect");
    
  } catch (e) {
    print("❌ Error configurando BLE iOS: $e");
    throw e;
  }
}
  
  // ✅ MOSTRAR NOTIFICACIÓN DE ESTADO
static Future<void> showStatusNotification(String message) async {
  if (_localNotifications == null) return;
  
  try {
    // ✅ CONFIGURACIÓN MÁXIMA PROMINENCIA PARA BLE
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,          // ✅ Mostrar alerta
      presentBadge: true,          // ✅ Mostrar badge
      presentSound: true,          // ✅ Reproducir sonido
      sound: 'default',            // ✅ Sonido por defecto del sistema
      interruptionLevel: InterruptionLevel.timeSensitive, // ✅ CRÍTICO: Interrumpe DND
      categoryIdentifier: 'BLE_CONNECTION',
      threadIdentifier: 'ble_status',
    );
    
    const NotificationDetails details = NotificationDetails(iOS: iosDetails);
    
    await _localNotifications!.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID único
      "🔵 Estado BLE",
      message,
      details,
    );
    
    print("✅ Notificación prominente iOS mostrada: $message");
    
  } catch (e) {
    print("❌ Error mostrando notificación prominente: $e");
  }
}

static Future<void> showCriticalBleNotification(String title, String message, {bool isDisconnection = false}) async {
  if (_localNotifications == null) return;
  
  try {
    // ✅ CONFIGURACIÓN CRÍTICA - MÁXIMA PROMINENCIA
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.critical,  // ✅ CRÍTICO: Ignora DND y silencio
      categoryIdentifier: 'BLE_CRITICAL',
      threadIdentifier: 'ble_critical',
      subtitle: 'Sistema BLE SOS',
    );
    
    const NotificationDetails details = NotificationDetails(iOS: iosDetails);
    
    // ID específico para BLE crítico
    int notificationId = isDisconnection ? 888 : 777;
    
    await _localNotifications!.show(
      notificationId,
      title,
      message,
      details,
    );
    
    print("✅ Notificación BLE CRÍTICA mostrada: $title - $message");
    
    // ✅ INTENTAR DESPERTAR PANTALLA (si es posible)
    try {
      print("📱 Notificación crítica debería encender pantalla automáticamente");
    } catch (e) {
      print("⚠️ No se pudo forzar despertar pantalla: $e");
    }
    
  } catch (e) {
    print("❌ Error mostrando notificación BLE crítica: $e");
  }
}


static Future<void> playSosAudioBackground() async {
  try {
    print("🔊 === REPRODUCIENDO AUDIO SOS EN BACKGROUND ===");
    
    // ✅ MÉTODO 1: Usar audioplayers con MP3 (más confiable para reproducción directa)
    try {
      final AudioPlayer audioPlayer = AudioPlayer();
      
      print("🔊 Reproduciendo audio MP3 con audioplayers...");
      await audioPlayer.play(AssetSource("sounds/alerta_sos.mp3"));
      print("✅ Audio SOS MP3 reproducido exitosamente");
      
      // Detener después de 3 segundos
      Timer(Duration(seconds: 3), () {
        audioPlayer.stop();
        audioPlayer.dispose();
        print("🔊 Audio SOS finalizado y recursos liberados");
      });
      
    } catch (audioError) {
      print("⚠️ Error reproduciendo audio MP3: $audioError");
    }
    
    // ✅ MÉTODO 2: Notificación con sonido WAV personalizado
    if (_localNotifications != null) {
      print("🔔 Enviando notificación SOS con sonido WAV personalizado...");
      
      try {
        // ✅ USAR WAV PARA NOTIFICACIONES (ahora que está en pubspec.yaml)
        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'alerta_sos.wav', // ✅ AHORA SÍ USAR WAV para notificaciones
          interruptionLevel: InterruptionLevel.critical,
          categoryIdentifier: 'SOS_AUDIO',
          threadIdentifier: 'sos_sound',
          subtitle: '🚨 ALERTA SOS ACTIVADA',
        );
        
        const NotificationDetails details = NotificationDetails(iOS: iosDetails);
        
        await _localNotifications!.show(
          998,
          "🚨 ALERTA SOS",
          "Botón de pánico activado - Enviando ubicación y alerta",
          details,
        );
        
        print("✅ Notificación SOS con sonido WAV personalizado mostrada");
        
      } catch (notificationError) {
        print("⚠️ Error en notificación SOS con WAV: $notificationError");
        
        // ✅ FALLBACK: Usar sonido por defecto si WAV falla
        try {
          print("🔄 Intentando con sonido por defecto...");
          const DarwinNotificationDetails fallbackDetails = DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            interruptionLevel: InterruptionLevel.critical,
            categoryIdentifier: 'SOS_AUDIO_FALLBACK',
          );
          
          await _localNotifications!.show(
            997,
            "🚨 ALERTA SOS",
            "Emergencia activada - Sistema de respaldo",
            const NotificationDetails(iOS: fallbackDetails),
          );
          
          print("✅ Notificación SOS con sonido por defecto (fallback) mostrada");
          
        } catch (fallbackError) {
          print("❌ Error incluso con fallback: $fallbackError");
        }
      }
    } else {
      print("⚠️ Notificaciones locales no disponibles para SOS");
    }
    
    print("🔊 === FIN REPRODUCCIÓN AUDIO SOS ===");
    
  } catch (e) {
    print("❌ Error general reproduciendo audio SOS: $e");
  }
}

static Future<bool> forceRequestNotificationPermissions() async {
  try {
    print("🔔 === FORZANDO SOLICITUD DE PERMISOS ===");
    
    if (_localNotifications == null) {
      await _setupLocalNotifications();
    }
    
    final iosImpl = _localNotifications!
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImpl != null) {
      print("📱 Solicitando permisos explícitamente...");
      
      // ✅ SOLICITAR TODOS LOS PERMISOS POSIBLES
      final bool? result = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true, // ✅ CRÍTICO para emergencias
      );
      
      print("📱 Resultado de solicitud: $result");
      
      // ✅ VERIFICAR USANDO permission_handler EN LUGAR DE checkPermissions()
      bool notificationPermission = await Permission.notification.isGranted;
      print("📱 Estado de permisos de notificación: $notificationPermission");
      
      // ✅ PROBAR NOTIFICACIÓN INMEDIATAMENTE
      if (result == true || notificationPermission) {
        print("✅ Permisos concedidos, probando notificación...");
        
        try {
          await _localNotifications!.show(
            999,
            "🎉 PERMISOS CONCEDIDOS",
            "Las notificaciones están funcionando correctamente",
            const NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.critical,
              ),
            ),
          );
          print("✅ Notificación de prueba enviada");
          return true;
        } catch (e) {
          print("⚠️ Error enviando notificación de prueba: $e");
          return false;
        }
      } else {
        print("❌ Permisos no concedidos");
        return false;
      }
      
    } else {
      print("❌ No se pudo obtener implementación iOS");
      return false;
    }
    
  } catch (e) {
    print("❌ Error forzando solicitud de permisos: $e");
    return false;
  }
}


static Future<String> checkCurrentPermissionStatus() async {
  try {
    // Método 1: permission_handler
    bool notificationGranted = await Permission.notification.isGranted;
    
    // Método 2: flutter_local_notifications
    String flutterLocalStatus = "No verificado";
    if (_localNotifications != null) {
      final iosImpl = _localNotifications!
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosImpl != null) {
        try {
          // ✅ USAR getNotificationAppLaunchDetails en lugar de checkPermissions
          final launchDetails = await _localNotifications!.getNotificationAppLaunchDetails();
          flutterLocalStatus = launchDetails != null ? "Inicializado" : "No inicializado";
        } catch (e) {
          flutterLocalStatus = "Error: $e";
        }
      }
    }
    
    String status = "permission_handler: ${notificationGranted ? 'Concedido' : 'Denegado'} | flutter_local: $flutterLocalStatus";
    print("📱 Estado completo de permisos: $status");
    
    return notificationGranted ? "Concedido" : "Denegado";
    
  } catch (e) {
    print("❌ Error verificando permisos: $e");
    return "Error: $e";
  }
}

  
  // ✅ LIMPIAR RECURSOS
  static Future<void> dispose() async {
    print("🧹 Limpiando recursos iOS...");
    
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _isInitialized = false;
    
    print("✅ Recursos iOS limpiados");
  }
  
  // ✅ VERIFICAR SI ESTÁ EJECUTÁNDOSE EN iOS
  static bool get isIOS => Platform.isIOS;
  
  // ✅ OBTENER ESTADO DE UBICACIÓN
  static bool get isLocationActive => _locationSubscription != null;
}

// ============================================================================
// ACTUALIZACIÓN PARA pubspec.yaml
// ============================================================================

/*
✅ AGREGAR AL pubspec.yaml:

dependencies:
  # ... dependencias existentes ...
  
  # ✅ CRÍTICO: Para notificaciones locales iOS
  flutter_local_notifications: ^17.2.2
  
  # ✅ VERIFICAR: Estas ya deberían estar
  flutter_blue_plus: ^1.35.3
  geolocator: ^9.0.0
  url_launcher: ^6.1.14

*/