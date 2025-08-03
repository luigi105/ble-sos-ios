import 'package:http/http.dart' as http;
import 'ble_data.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:audioplayers/audioplayers.dart';
import 'foreground.dart';
import 'ios_platform_manager.dart';
import 'dart:async';

class CommunicationService {
  static const MethodChannel _channel = MethodChannel('com.miempresa.ble_sos_ap/call');
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 🔹 Canal para traer la app al frente (Existente)
  static const MethodChannel _foregroundChannel = MethodChannel('com.miempresa.ble_sos_ap/foreground');
  
  // 🆕 Canal para notificaciones BLE y ubicación
  static const MethodChannel _notificationChannel = MethodChannel('com.miempresa.ble_sos_ap/notification');

  // Enviar señal de SOS al servidor
  Future<void> sendSosAlert(String? macAddress) async {
    const String url = "https://mmofusion.com/ble_alert.php";

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'device_id': BleData.imei,
          'mac_address': BleData.conBoton == 2 ? "N/A" : BleData.macAddress,
          'sos': '1',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Señal SOS enviada exitosamente: ${response.body}");
      } else {
        print("❌ Error en el servidor al enviar señal SOS: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Error en la solicitud POST de SOS: $e");
    }
  }
  
  Future<http.Response> sendLocation(
  String imei,
  double latitude,
  double longitude,
  String northSouth,
  String eastWest,
  String bleMacAddress,
  String activo,
  int batteryLevel,
  String cellOnline,
) async {
  const String url = "https://mmofusion.com/ble_location.php";

  try {
    final response = await http.post(
      Uri.parse(url),
      body: {
        'device_id': imei,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'north_south': northSouth,
        'east_west': eastWest,
        'mac_address': BleData.conBoton == 2 ? "N/A" : bleMacAddress,
        'activo': activo,
        'battery_level': batteryLevel.toString(),
        'cell_online': cellOnline,
      },
    );

    if (response.statusCode == 200) {
      print("✅ Respuesta del servidor: ${response.body}");
    } else {
      print("❌ Error en el servidor: Código ${response.statusCode}");
    }
    
    // Devolver la respuesta para que sendLocationOnce pueda verificarla
    return response;
    
  } catch (e) {
    print("⚠️ Error en la solicitud POST de ubicación: $e");
    // Crear una respuesta de error para mantener la consistencia del tipo de retorno
    throw e; // Re-lanzar la excepción para que sendLocationOnce la maneje
  }
}

  // Nueva función para obtener el MacAddress desde el IMEI y guardarlo
  // Modificar esta función en coms.dart
Future<void> fetchMacAddress(String imei) async {
  const String url = "https://mmofusion.com/get_address.php";

  try {
    print("🔍 iOS: Solicitando MAC Address para IMEI: $imei");
    
    final response = await http.post(
      Uri.parse(url),
      body: {'imei': imei},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      // ✅ DEBUGGING para iOS
      print("📡 iOS: Respuesta del servidor: $data");
      
      // Obtener y guardar MacAddress
      if (data.containsKey('mac_address') && data['mac_address'] != null) {
        String mac = data['mac_address'].toString();
        if (mac.isNotEmpty && mac != "null") {
          await BleData.setMacAddress(mac);
          print("✅ iOS: MacAddress recibido y guardado: $mac");
        } else {
          print("⚠️ iOS: MacAddress vacío o null en respuesta del servidor");
        }
      } else {
        print("⚠️ iOS: IMEI no encontrado en la base de datos o no tiene MacAddress asociado");
      }
      
      // Obtener y guardar número SOS
      if (data.containsKey('sos_number') && data['sos_number'] != null) {
        String sosNumber = data['sos_number'].toString();
        if (sosNumber.isNotEmpty && sosNumber != "null") {
          await BleData.setSosNumber(sosNumber);
          print("✅ iOS: Número SOS recibido y guardado: $sosNumber");
        } else {
          print("⚠️ iOS: Número SOS vacío en respuesta del servidor");
        }
      } else {
        print("⚠️ iOS: No se encontró número SOS asociado al IMEI");
      }
    } else {
      print("❌ iOS: Error en el servidor: ${response.statusCode}");
    }
  } catch (e) {
    print("⚠️ iOS: Error en la solicitud POST: $e");
  }
}

  Future<bool> checkImei(String imei) async {
    const String url = "https://mmofusion.com/checkimei.php";

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {'imei': imei},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('exists') && data['exists'] == true) {
          print("✅ IMEI válido y registrado.");
          return true;
        } else {
          print("❌ IMEI no registrado.");
          return false;
        }
      } else {
        print("❌ Error en el servidor: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("⚠️ Error en la solicitud POST: $e");
      return false;
    }
  }

  Future<bool> updateSosNumber(String nuevoTelefono) async {
    const String url = "https://mmofusion.com/update_sos_number.php";

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'imei': BleData.imei,
          'nuevo_numero': nuevoTelefono,
        },
      );

      if (response.statusCode == 200) {
        print("✅ Número de teléfono SOS actualizado.");
        return true;
      } else {
        print("❌ Error en la actualización del número SOS.");
        return false;
      }
    } catch (e) {
      print("⚠️ Error en la solicitud POST: $e");
      return false;
    }
  }

  Future<void> callSosNumber() async {
  String phoneNumber = BleData.sosNumber;

  if (phoneNumber.isEmpty || phoneNumber == "UNKNOWN_SOS") {
    print("⚠️ No hay número SOS configurado.");
    return;
  }

  // No iniciamos un nuevo servicio, simplemente actualizamos la notificación existente
  if (ForegroundService.isRunning) {
    await FlutterForegroundTask.updateService(
      notificationTitle: "Llamada SOS en progreso",
      notificationText: "Realizando llamada SOS a $phoneNumber",
    );
  }

  if (Platform.isAndroid) {
    try {
      await _channel.invokeMethod('callNumber', {"phone": phoneNumber});
    } on PlatformException catch (e) {
      print("❌ Error al hacer la llamada: ${e.message}");
    }
  } else if (Platform.isIOS) {
    final Uri url = Uri.parse("tel://$phoneNumber");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print("❌ No se pudo abrir el marcador en iOS.");
    }
  }

  // Después de la llamada, restaurar la notificación original
  if (ForegroundService.isRunning) {
    await Future.delayed(const Duration(seconds: 2));
    String notificationTitle = BleData.conBoton == 1 ? 'BLE SOS Service' : 'SOS Service';
    await FlutterForegroundTask.updateService(
      notificationTitle: notificationTitle,
      notificationText: 'Servicio activo',
    );
  }
}

  Future<bool> updateMacAddress(String macAddress) async {
    try {
      final response = await http.post(
       Uri.parse('https://mmofusion.com/update_macAddress.php'),
        body: {
          "imei": BleData.imei, // Enviar el IMEI actual para identificar el dispositivo
          "macAddress": macAddress,
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        print("✅ MacAddress actualizado en la base de datos.");
        return true;
      } else {
        print("❌ Error al actualizar MacAddress: ${data["error"]}");
        return false;
      }
    } catch (e) {
      print("❌ Error de conexión al actualizar MacAddress: $e");
      return false;
    }
  }

  // Método existente para mostrar notificación SOS
 Future<void> bringToForeground() async {
  // Verificar si las notificaciones SOS están habilitadas
  if (!BleData.sosNotificationEnabled) {
    print("🔕 Notificaciones SOS desactivadas, no se muestra notificación");
    return;
  }
  
  try {
    print("🔄 Intentando traer la app al frente...");
    
    if (Platform.isAndroid) {
      // Solo para Android
      await _foregroundChannel.invokeMethod('bringToForeground');
      print("✅ App traída al frente correctamente (Android).");
    } else if (Platform.isIOS) {
      // Para iOS, usar notificación local en lugar de traer al frente
      print("🍎 iOS: Mostrando notificación SOS en lugar de traer al frente");
      // iOS no permite traer apps al frente automáticamente
      // La notificación SOS ya se envía, no hacer nada más
    }
    
  } on PlatformException catch (e) {
    print("❌ Error al traer la app al frente: ${e.message}");
  } catch (e) {
    print("❌ Error general: $e");
  }
}

  // 🔹 Función para reproducir sonido de alerta SOS
Future<void> playSosSound() async {
  if (!BleData.sosSoundEnabled) {
    print("🔕 Sonido de alerta SOS deshabilitado, no se reproducirá.");
    return;
  }

  try {
    if (Platform.isIOS) {
      // ✅ iOS: Usar método específico de background
      await IOSPlatformManager.playSosAudioBackground();
      print("🔊 Sonido SOS iOS reproducido (background compatible)");
    } else {
      // Android: método existente
      await _audioPlayer.play(AssetSource("sounds/alerta_sos.mp3"));
      print("🔊 Sonido SOS Android reproducido");
    }
  } catch (e) {
    print("❌ Error al reproducir el sonido SOS: $e");
  }
}
  
 // Método para mostrar notificación cuando se pierde la conexión BLE
Future<void> showBleDisconnectedNotification() async {
  if (!BleData.bleNotificationsEnabled) {
    print("🔕 Notificaciones BLE desactivadas, no se muestra notificación");
    return;
  }
  
  try {
    print("🔄 Mostrando notificación de desconexión BLE...");
    
    if (Platform.isAndroid) {
      // Android: código existente
      await _notificationChannel.invokeMethod('showBleDisconnectedNotification');
      print("✅ Notificación Android enviada al canal nativo");
    } 
    else if (Platform.isIOS) {
      // ✅ iOS: USAR LA FUNCIÓN CORRECTA CON SONIDO
      await IOSPlatformManager.showCriticalBleNotification(
        "⚠️ BLE Desconectado", 
        "Dispositivo SOS desconectado. iOS intentará reconectar automáticamente. Verifique que esté encendido.",
        isDisconnection: true
      );
      
      // ✅ AGREGAR SONIDO SEPARADO
      if (BleData.sosSoundEnabled) {
        try {
          final AudioPlayer alertPlayer = AudioPlayer();
          await alertPlayer.play(AssetSource("sounds/alerta_sos.mp3"));
          print("🔊 Sonido de alerta BLE desconectado reproducido");
          
          // Detener después de 2 segundos
          Timer(Duration(seconds: 2), () {
            alertPlayer.stop();
            alertPlayer.dispose();
          });
        } catch (e) {
          print("⚠️ Error reproduciendo sonido de desconexión: $e");
        }
      }
      
      print("✅ Notificación BLE CRÍTICA iOS enviada con sonido");
    }
    
    print("✅ Notificación de desconexión BLE mostrada.");
  } catch (e) {
    print("❌ Error al mostrar notificación de desconexión BLE: $e");
  }
}

// Método para mostrar notificación cuando se recupera la conexión BLE
Future<void> showBleConnectedNotification() async {
  if (!BleData.bleNotificationsEnabled) {
    print("🔕 Notificaciones BLE desactivadas, no se muestra notificación");
    return;
  }
  
  try {
    print("🔄 Mostrando notificación de conexión BLE...");
    
    if (Platform.isAndroid) {
      // Android: código existente
      await _notificationChannel.invokeMethod('showBleConnectedNotification');
      print("✅ Notificación Android enviada al canal nativo");
    } 
    else if (Platform.isIOS) {
      // ✅ iOS: USAR LA FUNCIÓN CORRECTA CON SONIDO
      await IOSPlatformManager.showCriticalBleNotification(
        "🔵 BLE Conectado", 
        "Dispositivo SOS conectado y funcionando correctamente",
        isDisconnection: false
      );
      
      // ✅ AGREGAR SONIDO SUTIL PARA CONEXIÓN
      if (BleData.sosSoundEnabled) {
        try {
          final AudioPlayer connectPlayer = AudioPlayer();
          await connectPlayer.play(AssetSource("sounds/alerta_sos.mp3"));
          print("🔊 Sonido de conexión BLE reproducido");
          
          // Detener después de 1 segundo (más corto para conexión)
          Timer(Duration(seconds: 1), () {
            connectPlayer.stop();
            connectPlayer.dispose();
          });
        } catch (e) {
          print("⚠️ Error reproduciendo sonido de conexión: $e");
        }
      }
      
      print("✅ Notificación BLE PROMINENTE iOS enviada con sonido");
    }
    
    print("✅ Notificación de conexión BLE mostrada.");
  } catch (e) {
    print("❌ Error al mostrar notificación de conexión BLE: $e");
  }
}

// Método para mostrar notificación de estado de ubicación
Future<void> showLocationStatusNotification(bool confirmed) async {
   print("🔔 showLocationStatusNotification llamado con confirmed = $confirmed");
  // Verificar si las notificaciones BLE están habilitadas
  if (!BleData.bleNotificationsEnabled) {
    print("🔕 Notificaciones de ubicación desactivadas, no se muestra notificación");
    return;
  }
  
  try {
    print("🔄 Mostrando notificación de estado de ubicación...");
    
    // Para Android
    if (Platform.isAndroid) {
      // Usar el canal nativo para mostrar la notificación apropiada
      if (confirmed) {
        await _notificationChannel.invokeMethod('showLocationConfirmedNotification');
      } else {
        await _notificationChannel.invokeMethod('showLocationFailedNotification');
      }
    } 
    // Para iOS (si es necesario)
    else if (Platform.isIOS) {
      // Implementar para iOS si se requiere
    }
    
    print("✅ Notificación de estado de ubicación mostrada.");
  } catch (e) {
    print("❌ Error al mostrar notificación de estado de ubicación: $e");
  }
}

}