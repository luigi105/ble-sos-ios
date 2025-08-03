import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'coms.dart'; 
import 'ios_platform_manager.dart';

class BleData {
  static String macAddress = "N/A";
  static String imei = "UNKNOWN_IMEI"; 
  static String sosNumber = "N/A";
  static int batteryLevel = 0;
  static int rssi = -100; 
  static bool isConnected = false;
  static String deviceId = "UNKNOWN_DEVICE_ID";
  static bool locationConfirmed = false;
  static int conBoton = 0; 
  static bool autoCall = false; 
  static bool sosSoundEnabled = true;
  static bool sosNotificationEnabled = true; // Por defecto activado
  static bool bleNotificationsEnabled = true; // Para notificaciones de conexión BLE
  static bool prevConnectionState = false;
  static int locationFailureCount = 0;
  static int maxFailuresBeforeNotification = 5; // Notificacion red, norificaciones en "x"
  static int reconnectionAttemptCount = 0;
  static int maxReconnectionAttemptsBeforeNotification = 7; // Notificacion BLE, norificaciones en "x"
  static bool bleDisconnectionNotificationShown = false;
  static bool locationDisconnectionNotificationShown = false;  
  static DateTime? lastBleDisconnectionNotification; 
  static const Duration minimumNotificationInterval = Duration(minutes: 5);
  static DateTime? lastFailureTime;
  static bool firstBleConnection = true;  // Para primera conexión Bluetooth
  static bool firstLocationConfirmation = true;  // Para primera confirmación de ubicación
  static bool connectionNotificationsEnabled = true;  

  static StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  

  static Future<void> debugSharedPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  print("🔍 === DEBUG SHARED PREFERENCES ===");
  
  // Mostrar TODOS los valores guardados
  Set<String> keys = prefs.getKeys();
  print("📋 Claves encontradas en SharedPreferences:");
  
  if (keys.isEmpty) {
    print("   ✅ SharedPreferences está VACÍO (como debería estar en instalación nueva)");
  } else {
    print("   ❌ SharedPreferences tiene ${keys.length} valores guardados:");
    for (String key in keys) {
      dynamic value = prefs.get(key);
      print("   - $key: $value");
    }
  }
  
  // Verificar valores específicos que estamos cargando
  print("🔍 Valores específicos que estamos cargando:");
  print("   - conBoton: ${prefs.getInt('conBoton') ?? 'NO ENCONTRADO (debería ser null)'}");
  print("   - macAddress: ${prefs.getString('macAddress') ?? 'NO ENCONTRADO (debería ser null)'}");
  print("   - imei: ${prefs.getString('imei') ?? 'NO ENCONTRADO (debería ser null)'}");
  print("   - sosNumber: ${prefs.getString('sosNumber') ?? 'NO ENCONTRADO (debería ser null)'}");
  
  print("🔍 === FIN DEBUG SHARED PREFERENCES ===");
}

static Future<void> forceCleanForDevelopment() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  print("🗑️ === LIMPIEZA FORZADA PARA DESARROLLO ===");
  
  // Mostrar qué hay antes de limpiar
  Set<String> keysBefore = prefs.getKeys();
  print("📋 Antes de limpiar: ${keysBefore.length} claves");
  
  // Limpiar TODO
  bool cleared = await prefs.clear();
  print("🗑️ Resultado de clear(): $cleared");
  
  // Verificar después de limpiar
  Set<String> keysAfter = prefs.getKeys();
  print("📋 Después de limpiar: ${keysAfter.length} claves");
  
  // Resetear variables en memoria también
  conBoton = 0;
  macAddress = "N/A";
  imei = "UNKNOWN_IMEI";
  sosNumber = "UNKNOWN_SOS";
  autoCall = false;
  sosNotificationEnabled = true;
  bleNotificationsEnabled = true;
  
  print("✅ Variables en memoria también reseteadas");
  print("🔍 === FIN LIMPIEZA FORZADA ===");
}


static Future<void> checkFirstInstallAndCleanIfNeeded() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  print("🔍 === VERIFICACIÓN DE INSTALACIÓN ===");
  
  bool shouldClean = await shouldForceNewInstallation(prefs);
  
  if (shouldClean) {
    print("🗑️ Limpiando datos de instalación nueva...");
    await performCleanInstallation(prefs);
  } else {
    print("✅ Conservando datos de instalación existente");
    await performNormalInstallationCheck(prefs);
  }
  
  print("🔍 === FIN VERIFICACIÓN ===");
}

// 🆕 DETECTAR si debemos forzar nueva instalación

static Future<bool> shouldForceNewInstallation(SharedPreferences prefs) async {
  
  // 1️⃣ Si no hay NINGÚN dato, definitivamente es nueva
  Set<String> allKeys = prefs.getKeys();
  if (allKeys.isEmpty) {
    print("✅ SharedPreferences vacío = Nueva instalación");
    return true;
  }
  
  // 2️⃣ ✅ VERIFICAR MARKER DE INSTALACIÓN ANTES DE CUALQUIER OTRA COSA
  bool hasInstallMarker = prefs.containsKey('app_install_timestamp');
  if (!hasInstallMarker) {
    print("🚨 No hay marker de instalación - Primera vez o restore");
    // ✅ CREAR MARKER AHORA (no limpiar)
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('app_install_timestamp', currentTime);
    await prefs.setString('app_version_installed', "1.0.4");
    print("✅ Marker de instalación creado - NO limpiar datos existentes");
    return false; // ✅ NO LIMPIAR - solo faltaba el marker
  }
  
  // 3️⃣ ✅ SI HAY CONFIGURACIÓN VÁLIDA, CONSERVARLA
  String? savedImei = prefs.getString('imei');
  int? conBoton = prefs.getInt('conBoton');
  
  bool hasValidConfig = (savedImei != null && savedImei != "UNKNOWN_IMEI" && conBoton != null && conBoton != 0);
  
  if (hasValidConfig) {
    print("✅ Configuración válida encontrada - CONSERVAR datos");
    print("   - IMEI: $savedImei");
    print("   - conBoton: $conBoton");
    
    // ✅ ACTUALIZAR timestamp de uso
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('app_last_usage_timestamp', currentTime);
    
    return false; // ✅ NO LIMPIAR
  }
  
  // 4️⃣ ✅ SOLO LIMPIAR si datos están corruptos O incompletos
  if (savedImei == null || savedImei == "UNKNOWN_IMEI") {
    print("⚠️ IMEI no configurado - Nueva instalación requerida");
    return true;
  }
  
  if (conBoton == null || conBoton == 0) {
    print("⚠️ conBoton no configurado - Nueva instalación requerida");
    return true;
  }
  
  // 5️⃣ ✅ DEFAULT: CONSERVAR datos
  print("✅ Instalación legítima - conservando todos los datos");
  return false;
}

// 🧹 REALIZAR limpieza de nueva instalación
static Future<void> performCleanInstallation(SharedPreferences prefs) async {
  // Limpiar todo
  Set<String> keysBefore = prefs.getKeys();
  print("📋 Limpiando ${keysBefore.length} claves de posible cloud restore");
  
  await prefs.clear();
  _resetAllVariablesToDefault();
  
  // Establecer markers de nueva instalación
  String currentAppVersion = "1.0.4";
  int currentTime = DateTime.now().millisecondsSinceEpoch;
  
  await prefs.setString('app_version_installed', currentAppVersion);
  await prefs.setInt('app_install_timestamp', currentTime);
  await prefs.setInt('app_last_usage_timestamp', currentTime);
  
  print("✅ Nueva instalación configurada correctamente");
}

// 📋 VERIFICACIÓN normal para instalaciones existentes
static Future<void> performNormalInstallationCheck(SharedPreferences prefs) async {
  String currentAppVersion = "1.0.4";
  String? savedVersion = prefs.getString('app_version_installed');
  
  // Actualizar timestamp de uso
  int currentTime = DateTime.now().millisecondsSinceEpoch;
  await prefs.setInt('app_last_usage_timestamp', currentTime);
  
  // Verificar si es actualización de versión
  if (savedVersion != currentAppVersion) {
    print("🔄 Actualización detectada: $savedVersion → $currentAppVersion");
    await prefs.setString('app_version_installed', currentAppVersion);
  }
  
  print("✅ Instalación existente válida - Datos conservados");
}

// Método auxiliar para resetear todas las variables
static void _resetAllVariablesToDefault() {
  print("🔄 Reseteando todas las variables a valores por defecto...");
  
  // Variables principales
  conBoton = 0;
  macAddress = "N/A";
  imei = "UNKNOWN_IMEI";
  sosNumber = "UNKNOWN_SOS";
  deviceId = "UNKNOWN_DEVICE_ID";
  
  // Variables de configuración
  autoCall = false;
  sosSoundEnabled = true;
  sosNotificationEnabled = true;
  bleNotificationsEnabled = true;
  connectionNotificationsEnabled = true;
  
  // Variables de estado
  isConnected = false;
  locationConfirmed = false;
  batteryLevel = 0;
  rssi = -100;
  
  // Flags y contadores
  bleDisconnectionNotificationShown = false;
  locationDisconnectionNotificationShown = false;
  firstBleConnection = true;
  firstLocationConfirmation = true;
  locationFailureCount = 0;
  reconnectionAttemptCount = 0;
  
  // Timestamps
  lastBleDisconnectionNotification = null;
  lastFailureTime = null;
  
  print("✅ Todas las variables reseteadas a valores por defecto");
}

// Método nuclear para casos extremos de Samsung Cloud
static Future<void> nukePersistentDataForSamsung() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  print("💣 === ELIMINACIÓN NUCLEAR PARA SAMSUNG ===");
  
  // Lista COMPLETA de todas las claves que podría usar tu app
  List<String> allPossibleKeys = [
    'conBoton',
    'macAddress', 
    'imei',
    'sosNumber',
    'autoCall',
    'sosNotificationEnabled',
    'bleNotificationsEnabled',
    'connectionNotificationsEnabled',
    'lastConnectionState',
    'lastRssi',
    'lastBatteryLevel',
    'app_version_installed',
    'app_install_timestamp',
    'app_last_check_timestamp',
    // Agregar cualquier otra clave que puedas haber usado
  ];
  
  // Eliminar cada clave individualmente
  for (String key in allPossibleKeys) {
    bool removed = await prefs.remove(key);
    print("🗑️ Eliminando $key: $removed");
  }
  
  // Clear general por si acaso
  bool cleared = await prefs.clear();
  print("🗑️ Clear general: $cleared");
  
  // Verificar resultado
  Set<String> remainingKeys = prefs.getKeys();
  print("📋 Claves restantes: ${remainingKeys.length}");
  
  if (remainingKeys.isNotEmpty) {
    print("⚠️ CLAVES PERSISTENTES DE SAMSUNG CLOUD:");
    for (String key in remainingKeys) {
      dynamic value = prefs.get(key);
      print("   - $key: $value");
      // Intentar eliminar individualmente
      await prefs.remove(key);
    }
  }
  
  // Resetear variables en memoria
  _resetAllVariablesToDefault();
  
  print("💣 === FIN ELIMINACIÓN NUCLEAR ===");
}




static void update({
  String? newMacAddress,
  int? newBatteryLevel,
  int? newRssi,
  bool? connectionStatus,
}) {
  // Guardar el estado anterior para detectar cambios
  prevConnectionState = isConnected;
  
  if (newMacAddress != null) macAddress = newMacAddress;
  if (newBatteryLevel != null) batteryLevel = newBatteryLevel;
  if (newRssi != null) rssi = newRssi;
  if (connectionStatus != null) {
    // Verificar si ha cambiado el estado de conexión
    bool stateChanged = isConnected != connectionStatus;
    isConnected = connectionStatus;
    
  if (stateChanged) {
        print("🔄 Cambio de estado BLE: $prevConnectionState -> $isConnected");
        
        if (isConnected) {
          // ✅ COMENTAR notificación de conexión
          reconnectionAttemptCount = 0;
          print("✅ BLE conectado - contador reiniciado");
          
          /*
          // ✅ COMENTADO: Notificación de conexión no necesaria
          if (firstBleConnection && connectionNotificationsEnabled && conBoton == 1) {
            // CommunicationService().showBleConnectedNotification();
            firstBleConnection = false;
          }
          else if (connectionNotificationsEnabled && conBoton == 1 && bleDisconnectionNotificationShown) {
            // CommunicationService().showBleConnectedNotification();
            bleDisconnectionNotificationShown = false;
          }
          */
          
        } else {
          // ✅ MANTENER: Solo notificación de desconexión
          print("❌ BLE desconectado");
          if (connectionNotificationsEnabled && conBoton == 1 && bleNotificationsEnabled) {
            print("🔔 Enviando notificación de desconexión...");
            CommunicationService().showBleDisconnectedNotification();
            bleDisconnectionNotificationShown = true;
            markDisconnectionNotificationShown();
          }
        }
      }

    // ✅ NOTIFICACIONES ESPECÍFICAS iOS (código existente)
    if (Platform.isIOS && connectionStatus != null) {
      bool stateChanged = isConnected != connectionStatus;
      isConnected = connectionStatus;
      
      if (stateChanged) {
        if (isConnected) {
          IOSPlatformManager.showStatusNotification("🔵 Dispositivo BLE conectado");
        } else {
          IOSPlatformManager.showStatusNotification("⚠️ Dispositivo BLE desconectado - iOS intentará reconectar");
        }
      }
    }
    
    // Guardar estado de conexión cuando cambia
    saveConnectionState(connectionStatus);
  }

  print("Datos BLE actualizados:");
  print("MAC Address: $macAddress");
  print("Battery Level: $batteryLevel%");
  print("RSSI: $rssi dBm");
  print("Conexión Activa: $isConnected");
}

  
static void setLocationConfirmed(bool status) {

    // ✅ MANEJO ESPECÍFICO iOS
  if (Platform.isIOS) {
    bool previousState = locationConfirmed;
    locationConfirmed = status;
    
    if (status && !previousState) {
      IOSPlatformManager.showStatusNotification("📍 Ubicación confirmada - Cambios significativos monitoreados");
    } else if (!status && previousState) {
      IOSPlatformManager.showStatusNotification("⚠️ Error enviando ubicación");
    }
    
    return; // Salir temprano para iOS
  }

  // Agregar protección contra cambios rápidos de estado
  if (!status) {
    // Si estamos marcando como fallo, registrar el tiempo
    lastFailureTime = DateTime.now();
  } else if (lastFailureTime != null) {
    // Si estamos marcando como éxito después de un fallo reciente
    Duration timeSinceFailure = DateTime.now().difference(lastFailureTime!);
    if (timeSinceFailure < Duration(seconds: 5)) {
      print("⚠️ Intento de marcar como éxito demasiado pronto después de un fallo (${timeSinceFailure.inSeconds}s). Ignorando.");
      return; // Ignorar este intento de marcar como éxito
    }
  }
  
  // Guardar el estado anterior
  bool previousState = locationConfirmed;
  
  // Manejar el caso de éxito
  if (status) {
    bool stateChanged = previousState != status;
    
    if (stateChanged) {
      print("🔄 Cambio de estado de confirmación: $previousState -> $status");
      locationConfirmed = status;
      
      // Si la comunicación se recupera, reiniciamos el contador
      locationFailureCount = 0;
      print("Confirmación de ubicación: EXITOSA ✅ | Contador de fallos reiniciado: 0");
    }
    
    // Caso especial: Primera confirmación de ubicación después de iniciar la app
    if (firstLocationConfirmation && connectionNotificationsEnabled) {
      print("🔔 Primera confirmación de ubicación detectada. Mostrando notificación inicial.");
      CommunicationService().showLocationStatusNotification(true);
      firstLocationConfirmation = false;  // Marcar que ya se mostró la primera notificación
    } 
    // Caso normal: Reconexión después de una notificación de desconexión
    else if (stateChanged && previousState == false && locationDisconnectionNotificationShown && connectionNotificationsEnabled) {
      print("✅ Conexión recuperada: Mostrando notificación de éxito (después de notificación de fallo)");
      CommunicationService().showLocationStatusNotification(true);
      // Reiniciar la bandera después de mostrar la notificación
      locationDisconnectionNotificationShown = false;
    } 
    else if (stateChanged) {
      print("✅ Conexión recuperada: No se muestra notificación porque no se alcanzó el umbral de fallos previamente");
    }
  } 
  // Manejar el caso de fallo - aunque no haya cambio de estado
  else if (!status) {
    // Establecer el estado si es necesario
    if (previousState != status) {
      locationConfirmed = status;
      print("🔄 Cambio de estado de confirmación: $previousState -> $status");
    } else {
      print("📌 Estado de confirmación sin cambios (sigue en: $status)");
    }
    
    // Primera confirmación fallida no debería mostrar notificación
    if (firstLocationConfirmation) {
      firstLocationConfirmation = false;
      print("📌 Primera confirmación falló, pero no se muestra notificación por ser la primera");
      locationFailureCount = 0; // Reiniciamos para que comience el conteo apropiadamente
    } else {
      // Siempre incrementar el contador cuando se marque como fallido (después de la primera vez)
      locationFailureCount++;
      print("Confirmación de ubicación: FALLIDA ❌ | Contador de fallos: $locationFailureCount/$maxFailuresBeforeNotification");
      
      // Solo mostrar la notificación de FALLO cuando alcanzamos exactamente el umbral,
      // independientemente de si hubo cambio de estado o no
      if (locationFailureCount == maxFailuresBeforeNotification) {
        print("❌ Umbral de fallos alcanzado: Mostrando notificación de fallo");
        
        // Solo mostrar notificación si están habilitadas
        if (connectionNotificationsEnabled) {
          CommunicationService().showLocationStatusNotification(false);
          locationDisconnectionNotificationShown = true;  // Marcar que se mostró la notificación
        }
      }
    }
  }
}
  
  // Método para actualizar el deviceId
  static void setDeviceId(String newDeviceId) {
    deviceId = newDeviceId;
    print("ID único del dispositivo actualizado: $deviceId");
  }

  // Guardar y cargar la configuración de conBoton
  static Future<void> setConBoton(int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('conBoton', value);
    conBoton = value;
    print("conBoton actualizado: $conBoton");
  }

  static Future<void> loadConBoton() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    conBoton = prefs.getInt('conBoton') ?? 0;
    print("conBoton cargado: $conBoton");
  }

  // Guardar y cargar el MacAddress
  static Future<void> setMacAddress(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('macAddress', value);
    macAddress = value;
    print("MacAddress actualizado: $macAddress");
  }

  static Future<void> loadMacAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    macAddress = prefs.getString('macAddress') ?? "N/A";
    print("MacAddress cargado: $macAddress");
  }

  static Future<void> clearMacAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('macAddress');
    macAddress = "N/A";
    print("🗑️ MacAddress eliminado");
  }

  static Future<void> setImei(String newImei) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('imei', newImei);
    imei = newImei;
    print("IMEI guardado: $imei");
  }

  static Future<void> loadImei() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    imei = prefs.getString('imei') ?? "UNKNOWN_IMEI";
    print("IMEI cargado: $imei");
  }

  static Future<void> setSosNumber(String newNumber) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('sosNumber', newNumber);
    sosNumber = newNumber;
    print("📌 Número SOS guardado: $sosNumber");
  }

  static Future<void> loadSosNumber() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    sosNumber = prefs.getString('sosNumber') ?? "UNKNOWN_SOS";
    print("📌 Número SOS cargado: $sosNumber");
  }

  static void restartApp() {
    exit(0);
  }

  // Guardar y cargar la configuración de Llamado Automático
  static Future<void> setAutoCall(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoCall', value);
    autoCall = value;
    print("📞 Llamado Automático actualizado: $autoCall");
  }

  static Future<void> loadAutoCall() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    autoCall = prefs.getBool('autoCall') ?? false;
    print("📞 Llamado Automático cargado: $autoCall");
  }

  static Future<void> setSosSoundEnabled(bool value) async {
    sosSoundEnabled = value;
    // Guarda la preferencia en almacenamiento local (si usas SharedPreferences, agrégalo aquí)
  }

  // Añade un método para cancelar la suscripción al estado de conexión
  static void cancelConnectionSubscription() {
    connectionSubscription?.cancel();
    connectionSubscription = null;
  }
  
  // Para limpiar recursos cuando la app se cierra
  // Modificar el método dispose en ble_data.dart:

// Para limpiar recursos cuando la app se cierra
static void dispose() {
  print("🧹 Limpiando recursos de BleData...");
  
  // Cancelar suscripción de conexión BLE
  cancelConnectionSubscription();
  
  // Resetear banderas de estado
  bleDisconnectionNotificationShown = false;
  locationDisconnectionNotificationShown = false;
  firstBleConnection = true;
  firstLocationConfirmation = true;
  
  // Resetear contadores
  locationFailureCount = 0;
  reconnectionAttemptCount = 0;
  
  // Limpiar timestamps
  lastBleDisconnectionNotification = null;
  lastFailureTime = null;
  
  print("✅ Recursos de BleData limpiados");
}

  // Método para guardar el último estado de conexión
  static Future<void> saveConnectionState(bool isConnected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lastConnectionState', isConnected);
  }
  
  // Método para cargar el último estado de conexión conocido
  static Future<bool> loadLastConnectionState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('lastConnectionState') ?? false;
  }
  
  // Método para guardar el último rssi conocido
  static Future<void> saveLastRssi(int rssi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastRssi', rssi);
  }
  
  // Método para cargar el último rssi conocido
  static Future<int> loadLastRssi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lastRssi') ?? 0;
  }
  
  // Método para guardar el último nivel de batería conocido
  static Future<void> saveLastBatteryLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastBatteryLevel', level);
  }
  
  // Método para cargar el último nivel de batería conocido
  static Future<int> loadLastBatteryLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lastBatteryLevel') ?? 0;
  }
  
  // Carga todos los datos guardados al iniciar la app
  static Future<void> loadAllSavedData() async {
    await loadConBoton();
    await loadMacAddress();
    await loadImei();
    await loadSosNumber();
    await loadAutoCall();
    await loadSosNotificationEnabled();
    await loadBleNotificationsEnabled(); // Cargar configuración de notificaciones BLE
    
    // Cargar último estado de conexión conocido
    int lastRssi = await loadLastRssi();
    int lastBatteryLevel = await loadLastBatteryLevel();
    
    // Actualizar los datos con la información guardada
    BleData.update(
      newRssi: lastRssi,
      newBatteryLevel: lastBatteryLevel,
      connectionStatus: false // Iniciamos desconectado aunque el último estado fuera conectado
    );
  }

  // Método para guardar la configuración de notificaciones SOS
  static Future<void> setSosNotificationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sosNotificationEnabled', value);
    sosNotificationEnabled = value;
    print("📱 Notificaciones SOS: $sosNotificationEnabled");
  }

  // Método para cargar la configuración de notificaciones SOS
  static Future<void> loadSosNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    sosNotificationEnabled = prefs.getBool('sosNotificationEnabled') ?? true; // Por defecto true
    print("📱 Notificaciones SOS cargadas: $sosNotificationEnabled");
  }
  
  // Método para guardar la configuración de notificaciones BLE
  static Future<void> setBleNotificationsEnabled(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bleNotificationsEnabled', value);
    bleNotificationsEnabled = value;
    print("📱 Notificaciones BLE: $bleNotificationsEnabled");
  }

  // Método para cargar la configuración de notificaciones BLE
  static Future<void> loadBleNotificationsEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bleNotificationsEnabled = prefs.getBool('bleNotificationsEnabled') ?? true; // Por defecto true
    print("📱 Notificaciones BLE cargadas: $bleNotificationsEnabled");
  }

  // Verificar si se debe mostrar notificación de desconexión
  static bool shouldShowDisconnectionNotification() {
    // Si nunca se ha mostrado una notificación, permitir mostrarla
    if (lastBleDisconnectionNotification == null) {
      return true;
    }
    
    // Solo permitir mostrar una notificación si ha pasado el intervalo mínimo
    DateTime now = DateTime.now();
    return now.difference(lastBleDisconnectionNotification!) > minimumNotificationInterval;
  }

  // Marcar que se ha mostrado una notificación de desconexión
  static void markDisconnectionNotificationShown() {
    lastBleDisconnectionNotification = DateTime.now();
    bleDisconnectionNotificationShown = true;  // Configurar la bandera para reconexión
    print("📱 Notificación de desconexión BLE mostrada y marcada a las ${lastBleDisconnectionNotification!.hour}:${lastBleDisconnectionNotification!.minute}");
  }


  // Método para forzar un cambio de estado sin esperar a que falle múltiples veces
static void forceLocationDisconnected() {
  if (locationConfirmed) {
    print("⚠️ Forzando cambio de estado a desconectado");
    locationConfirmed = false;
    locationFailureCount = maxFailuresBeforeNotification; // Forzar para que se muestre la notificación
    
    // Solo mostrar notificación si están habilitadas
    if (bleNotificationsEnabled) {
      print("📱 Mostrando notificación de desconexión forzada");
      CommunicationService().showLocationStatusNotification(false);
      locationDisconnectionNotificationShown = true;
    }
  }
}

static Future<bool> isInternetConnected() async {
  try {
    final result = await InternetAddress.lookup('mmofusion.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } catch (_) {}
  return false;
}

static Future<void> setConnectionNotificationsEnabled(bool value) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool('connectionNotificationsEnabled', value);
  connectionNotificationsEnabled = value;
  print("📱 Notificaciones de Conexión: $connectionNotificationsEnabled");
}

static Future<void> loadConnectionNotificationsEnabled() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  connectionNotificationsEnabled = prefs.getBool('connectionNotificationsEnabled') ?? true; // Por defecto true
  print("📱 Notificaciones de Conexión cargadas: $connectionNotificationsEnabled");
}


Future<void> showBleDisconnectedNotification() async {
  // Verificar si las notificaciones de conexión están habilitadas
  if (!BleData.connectionNotificationsEnabled) {
    print("🔕 Notificaciones de conexión desactivadas, no se muestra notificación");
    return;
  }
  
  try {
    // El resto del método sigue igual...
  } catch (e) {
    print("❌ Error al mostrar notificación de desconexión BLE: $e");
  }
}

}