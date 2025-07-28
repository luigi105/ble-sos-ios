// Versión mejorada para la clase BleDeviceHandler
/*
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'ble_data.dart';
import 'coms.dart';
import 'package:flutter/material.dart';

// Clase para manejar diferentes marcas de dispositivos BLE
class BleDeviceHandler {
  // Enumeración de marcas soportadas
  static const int BLE_DEVICE_UNKNOWN = 0;
  static const int BLE_DEVICE_HOLYIOT = 1;
  static const int BLE_DEVICE_HONYCOMM = 2;

  // Nombres exactos de los dispositivos
  static const String HOLYIOT_DEVICE_NAME = "Holy-IOT";
  static const String HONYCOMM_DEVICE_NAME = "HCBB31SOS";

  // UUIDs para HolyIoT
  static const String HOLYIOT_SERVICE_UUID = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String HOLYIOT_WRITE_UUID = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String HOLYIOT_NOTIFY_UUID = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
  
  // UUIDs para Honycomm (si no están definidos explícitamente, podríamos detectarlos dinámicamente)
  static const String HONYCOMM_SERVICE_UUID_SHORT = '4b4c';
  
  // Lista para registrar datos históricos para depuración
  static List<List<int>> honycommDataHistory = [];
  static const int MAX_HISTORY_SIZE = 20; // Mantener solo las últimas 20 muestras
  
  // Función para detectar el tipo de dispositivo basado en el nombre durante el escaneo
  static int detectDeviceTypeFromName(String deviceName) {
    if (deviceName == HOLYIOT_DEVICE_NAME) {
      return BLE_DEVICE_HOLYIOT;
    } else if (deviceName == HONYCOMM_DEVICE_NAME) {
      return BLE_DEVICE_HONYCOMM;
    }
    return BLE_DEVICE_UNKNOWN;
  }
  
  // Función para detectar automáticamente el tipo de dispositivo
  static Future<int> detectDeviceType(BluetoothDevice device) async {
    try {
      print("Detectando tipo de dispositivo para: ${device.remoteId}");
      
      // Si ya tenemos un tipo configurado manualmente, usarlo
      int configuredType = BleData.deviceType;
      if (configuredType != BLE_DEVICE_UNKNOWN) {
        print("📱 Usando tipo de dispositivo configurado manualmente: $configuredType");
        return configuredType;
      }
      
      // Verificar nombre exacto del dispositivo (método más confiable)
      String deviceName = device.platformName;
      print("Nombre del dispositivo: $deviceName");
      
      if (deviceName == HOLYIOT_DEVICE_NAME) {
        print("✅ Dispositivo identificado como HolyIoT por nombre exacto");
        await BleData.setDeviceType(BLE_DEVICE_HOLYIOT);
        return BLE_DEVICE_HOLYIOT;
      } else if (deviceName == HONYCOMM_DEVICE_NAME) {
        print("✅ Dispositivo identificado como Honycomm por nombre exacto");
        await BleData.setDeviceType(BLE_DEVICE_HONYCOMM);
        return BLE_DEVICE_HONYCOMM;
      }
      
      // Si el nombre contiene partes del nombre exacto
      if (deviceName.contains("Holy") || deviceName.contains("IOT")) {
        print("✅ Dispositivo identificado como posible HolyIoT por nombre parcial");
        await BleData.setDeviceType(BLE_DEVICE_HOLYIOT);
        return BLE_DEVICE_HOLYIOT;
      } else if (deviceName.contains("HC") || deviceName.contains("SOS")) {
        print("✅ Dispositivo identificado como posible Honycomm por nombre parcial");
        await BleData.setDeviceType(BLE_DEVICE_HONYCOMM);
        return BLE_DEVICE_HONYCOMM;
      }
      
      // Si tenemos un tipo detectado temporalmente durante el escaneo, usarlo
      if (BleData.tempDetectedType != BLE_DEVICE_UNKNOWN) {
        print("📱 Usando tipo de dispositivo detectado durante escaneo: ${BleData.tempDetectedType}");
        return BleData.tempDetectedType;
      }
      
      // Intentar descubrir servicios
      print("🔍 Descubriendo servicios para detectar tipo de dispositivo...");
      List<BluetoothService> services = await device.discoverServices();
      
      // Imprimir todos los servicios encontrados para depuración
      print("Servicios encontrados:");
      for (var service in services) {
        print("UUID: ${service.uuid}");
        for (var characteristic in service.characteristics) {
          print("  - Char: ${characteristic.uuid} - Props: ${characteristic.properties}");
        }
      }
      
      // Comprobar si es un dispositivo HolyIoT
      bool isHolyIoT = services.any((service) => 
        service.uuid.toString().toLowerCase().contains(HOLYIOT_SERVICE_UUID));
      
      if (isHolyIoT) {
        print("✅ Dispositivo detectado como HolyIoT por servicio UUID");
        await BleData.setDeviceType(BLE_DEVICE_HOLYIOT);
        return BLE_DEVICE_HOLYIOT;
      }
      
      // Comprobar si es un dispositivo Honycomm
      bool isHonycomm = services.any((service) => 
        service.uuid.toString().toLowerCase().contains(HONYCOMM_SERVICE_UUID_SHORT));
      
      if (isHonycomm) {
        print("✅ Dispositivo detectado como Honycomm por servicio UUID");
        await BleData.setDeviceType(BLE_DEVICE_HONYCOMM);
        return BLE_DEVICE_HONYCOMM;
      }
      
      // Si no se puede detectar, usar la auto-detección genérica que intentará todos los protocolos
      print("⚠️ No se pudo detectar el tipo específico. Usando auto-detección genérica.");
      return BLE_DEVICE_UNKNOWN;
      
    } catch (e) {
      print("❌ Error al detectar tipo de dispositivo: $e");
      // Si hay un error en la detección, dejarlo como desconocido
      return BLE_DEVICE_UNKNOWN;
    }
  }
  
  // Función para monitorear notificaciones según el tipo de dispositivo
  static Future<void> setupNotifications(BluetoothDevice device, int deviceType, Function onSosActivated) async {
    try {
      print("🔔 Configurando notificaciones para dispositivo tipo: $deviceType");
      
      if (deviceType == BLE_DEVICE_HOLYIOT) {
        await setupHolyIoTNotifications(device, onSosActivated);
      } else if (deviceType == BLE_DEVICE_HONYCOMM) {
        await setupHonycommNotifications(device, onSosActivated);
      } else {
        print("⚠️ Tipo de dispositivo desconocido o auto-detección, intentando ambos protocolos");
        
        // Intentar ambos protocolos, comenzando con el más común (HolyIoT)
        try {
          await setupHolyIoTNotifications(device, onSosActivated);
          print("✅ Notificaciones HolyIoT configuradas correctamente");
        } catch (e) {
          print("⚠️ Error al configurar notificaciones HolyIoT: $e");
          try {
            await setupHonycommNotifications(device, onSosActivated);
            print("✅ Notificaciones Honycomm configuradas correctamente");
          } catch (e) {
            print("❌ Error al configurar notificaciones Honycomm: $e");
            // Como último recurso, intentar encontrar cualquier característica con notificación
            await setupGenericNotifications(device, onSosActivated);
          }
        }
      }
    } catch (e) {
      print("❌ Error general al configurar notificaciones: $e");
      // Intentar configuración genérica como último recurso
      await setupGenericNotifications(device, onSosActivated);
    }
  }
  
  // Configurar notificaciones genéricas para cualquier dispositivo
  static Future<void> setupGenericNotifications(BluetoothDevice device, Function onSosActivated) async {
    print("🔍 Buscando características con notificación en cualquier servicio...");
    
    List<BluetoothService> services = await device.discoverServices();
    bool foundAnyNotifyCharacteristic = false;
    
    for (var service in services) {
      print("Comprobando servicio: ${service.uuid}");
      
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          print("✅ Encontrada característica con notificación: ${characteristic.uuid}");
          foundAnyNotifyCharacteristic = true;
          
          await characteristic.setNotifyValue(true);
          
          // Escuchar las notificaciones e intentar interpretarlas
          characteristic.value.listen((value) {
            if (value.isNotEmpty) {
              print("📊 Datos recibidos en notificación genérica: $value");
              
              // Guardar datos para análisis histórico
              addToDataHistory(value);
              
              // Intentar detectar patrones de SOS en los datos usando diferentes métodos
              
              // Método 1: HolyIoT típico - Si comienza con F3 15 F3 y el byte 4 es 1
              if (value.length >= 5 && 
                  value[0] == 0xF3 && 
                  value[1] == 0x15 && 
                  value[2] == 0xF3 && 
                  value[4] == 1) {
                print("🔔 Posible SOS de HolyIoT detectado");
                triggerSosAlert(device, onSosActivated);
              }
              
              // Método 2: valor simple en índice 4 (como en implementación original)
              if (value.length > 4 && value[4] == 1) {
                print("🔔 Posible SOS detectado por valor en índice 4");
                triggerSosAlert(device, onSosActivated);
              }
              
              // Método 3: Honycomm - Si el byte 12 tiene el bit 5 activo
              if (value.length > 12) {
                int statusByte = value[12];
                bool isSosActive = (statusByte & 0x20) != 0; // Comprobar bit 5
                if (isSosActive) {
                  print("🔔 Posible SOS de Honycomm detectado (bit 5 activo en byte 12)");
                  triggerSosAlert(device, onSosActivated);
                }
              }
              
              // Método 4: Honycomm alternativo - bits específicos en cualquier posición
              checkHonycommPatterns(value, device, onSosActivated);
              
              // Intentar leer nivel de batería independientemente del protocolo
              tryExtractBatteryLevel(value);
            }
          });
        }
      }
    }
    
    if (!foundAnyNotifyCharacteristic) {
      print("⚠️ No se encontraron características con notificación en ningún servicio");
    }
  }
  
  // Añadir datos al historial para análisis
  static void addToDataHistory(List<int> data) {
    honycommDataHistory.add(List<int>.from(data));
    if (honycommDataHistory.length > MAX_HISTORY_SIZE) {
      honycommDataHistory.removeAt(0);
    }
    
    // Imprimir resumen del historial para análisis
    if (honycommDataHistory.length % 5 == 0) {
      print("🔄 Historial de datos recibidos (últimas ${honycommDataHistory.length} muestras):");
      for (var i = 0; i < honycommDataHistory.length; i++) {
        print("  Muestra $i: ${honycommDataHistory[i]}");
      }
    }
  }
  
  // Verificar patrones específicos de Honycomm
  static void checkHonycommPatterns(List<int> value, BluetoothDevice device, Function onSosActivated) {
    // Buscar bits específicos en diferentes posiciones que podrían indicar SOS
    for (int i = 0; i < value.length; i++) {
      int byte = value[i];
      
      // Comprobar bits específicos (5, 6, 7) que podrían indicar SOS
      if ((byte & 0x20) != 0) { // Bit 5
        print("🔍 Bit 5 activo en byte $i: $byte");
      }
      if ((byte & 0x40) != 0) { // Bit 6
        print("🔍 Bit 6 activo en byte $i: $byte");
      }
      if ((byte & 0x80) != 0) { // Bit 7
        print("🔍 Bit 7 activo en byte $i: $byte");
      }
      
      // Si vemos un patrón que podría ser un botón SOS
      if ((byte & 0x20) != 0 && (byte != 0xFF)) { // Bit 5 activo pero no todos los bits (0xFF)
        print("🚨 Posible SOS detectado por patrón de bits en byte $i");
        // No activamos directamente para evitar falsos positivos
        // Solo lo hacemos si vemos patrones consistentes
      }
    }
    
    // Verificar patrones consistentes en múltiples muestras
    if (honycommDataHistory.length >= 3) {
      // Si las últimas 3 muestras tienen el mismo patrón en el mismo byte
      // y ese patrón podría indicar un SOS, entonces activamos la alerta
      
      var lastSamples = honycommDataHistory.sublist(honycommDataHistory.length - 3);
      
      // Verificar si todas las muestras tienen la misma longitud y datos similares
      if (lastSamples.every((sample) => sample.length == lastSamples[0].length)) {
        int sampleLength = lastSamples[0].length;
        
        // Verificar cada posición para patrones consistentes
        for (int i = 0; i < sampleLength; i++) {
          if (i < lastSamples[0].length && 
              i < lastSamples[1].length && 
              i < lastSamples[2].length) {
            
            // Si vemos el mismo byte con bit 5 activo en las 3 muestras
            int b1 = lastSamples[0][i];
            int b2 = lastSamples[1][i];
            int b3 = lastSamples[2][i];
            
            if ((b1 & 0x20) != 0 && (b2 & 0x20) != 0 && (b3 & 0x20) != 0) {
              print("🚨 PATRÓN CONSISTENTE DETECTADO: bit 5 activo en byte $i en 3 muestras consecutivas");
              triggerSosAlert(device, onSosActivated);
              break;
            }
          }
        }
      }
    }
  }
  
  // Intentar extraer nivel de batería de los datos
  static void tryExtractBatteryLevel(List<int> value) {
    try {
      // Método 1: Protocolo HolyIoT - F3 16 F3 seguido de longitud y nivel
      if (value.length >= 5 && 
          value[0] == 0xF3 && 
          value[1] == 0x16 && 
          value[2] == 0xF3) {
        
        int batteryLevel = value[4];
        print("📊 Nivel de batería detectado (HolyIoT): $batteryLevel%");
        BleData.update(newBatteryLevel: batteryLevel);
        return;
      }
      
      // Método 2: Protocolo Honycomm - bytes 2-3 como voltaje en mV (0-3600)
      if (value.length > 3) {
        // En el protocolo Honycomm, la batería está en los bytes 2-3 como voltaje en mV
        try {
          int batteryVoltage = (value[2] << 8) | value[3];
          
          // Si es un valor razonable para voltaje de batería (entre 2000-4200 mV)
          if (batteryVoltage >= 2000 && batteryVoltage <= 4200) {
            // Convertir voltaje a porcentaje (ajustar según las especificaciones reales del dispositivo)
            // Asumiendo batería LiPo típica: 3.0V = 0%, 4.2V = 100%
            int batteryPercentage = ((batteryVoltage - 3000) / 1200 * 100).round();
            batteryPercentage = batteryPercentage.clamp(0, 100);
            
            print("📊 Nivel de batería detectado (Honycomm): ${batteryVoltage}mV ($batteryPercentage%)");
            BleData.update(newBatteryLevel: batteryPercentage);
            return;
          }
        } catch (e) {
          // Ignorar errores en este intento
        }
      }
      
      // Método 3: Buscar un byte individual que podría representar porcentaje (0-100)
      for (int i = 0; i < value.length; i++) {
        int byte = value[i];
        // Si el valor está entre 0-100, podría ser un porcentaje de batería
        if (byte >= 0 && byte <= 100) {
          // No actualizamos directamente para evitar falsos positivos
          // Solo lo registramos para análisis
          print("🔍 Posible porcentaje de batería en byte $i: $byte%");
        }
      }
      
      // Método 4: Si hay un byte 16 (0x10) presente, podría indicar comando de batería
      int index = value.indexOf(0x10);
      if (index >= 0 && index + 1 < value.length) {
        int possibleBatteryLevel = value[index + 1];
        if (possibleBatteryLevel >= 0 && possibleBatteryLevel <= 100) {
          print("🔍 Posible nivel de batería después de byte 0x10: $possibleBatteryLevel%");
          // Solo registramos, no actualizamos directamente
        }
      }
    } catch (e) {
      // Ignorar errores en intentos de extraer batería
    }
  }
  
  // Función para desencadenar la alerta SOS
  static void triggerSosAlert(BluetoothDevice device, Function onSosActivated) {
    if (BleData.buttonPressed && BleData.panicTimer != null) {
      // Ya está en proceso una alerta, no duplicar
      return;
    }
    
    BleData.buttonPressed = true;
    BleData.panicTimer = Timer(const Duration(seconds: 3), () {
      if (BleData.buttonPressed) {
        print("¡Botón SOS presionado! Generando alerta...");
        
        // 🔊 Reproducir sonido de alerta
        if (BleData.sosSoundEnabled) {
          CommunicationService().playSosSound();
        }
        
        // 🔹 Intentamos traer la app al frente
        CommunicationService().bringToForeground();
        
        // Activar SOS en la UI
        onSosActivated();
        
        // 📌 Enviar alerta SOS
        CommunicationService().sendSosAlert(device.remoteId.toString());
        
        // 📞 Llamada automática si está activada en la configuración
        if (BleData.autoCall) {
          Future.delayed(const Duration(seconds: 1), () {
            CommunicationService().callSosNumber();
          });
        }
      }
      BleData.panicTimer = null;
    });
  }
  
  // Configurar notificaciones para dispositivos HolyIoT
  static Future<void> setupHolyIoTNotifications(BluetoothDevice device, Function onSosActivated) async {
    print("Configurando notificaciones para HolyIoT: ${device.remoteId}");
    
    List<BluetoothService> services = await device.discoverServices();
    bool found = false;
    
    for (var service in services) {
      String serviceUuid = service.uuid.toString().toLowerCase();
      print("Comprobando servicio: $serviceUuid");
      
      if (serviceUuid.contains(HOLYIOT_SERVICE_UUID.toLowerCase())) {
        print("✅ Encontrado servicio HolyIoT");
        found = true;
        
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            print("✅ Encontrada característica con notificación: ${characteristic.uuid}");
            
            await characteristic.setNotifyValue(true);
            
            // Monitorear notificaciones para HolyIoT
            characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                print("Valor recibido de HolyIoT: $value");
                
                // Guardar datos para análisis histórico
                addToDataHistory(value);
                
                // Verificar si es una notificación de botón (método original)
                if (value.length > 4 && value[4] == 1 && !BleData.buttonPressed && BleData.panicTimer == null) {
                  BleData.buttonPressed = true;
                  BleData.panicTimer = Timer(const Duration(seconds: 3), () {
                    if (BleData.buttonPressed) {
                      print("¡Botón SOS HolyIoT presionado! Generando alerta...");
                      
                      // 🔊 Reproducir sonido de alerta
                      if (BleData.sosSoundEnabled) {
                        CommunicationService().playSosSound();
                      }
                      
                      // 🔹 Intentamos traer la app al frente
                      CommunicationService().bringToForeground();
                      
                      // Activar SOS en la UI
                      onSosActivated();
                      
                      // 📌 Enviar alerta SOS
                      CommunicationService().sendSosAlert(device.remoteId.toString());
                      
                      // 📞 Llamada automática si está activada en la configuración
                      if (BleData.autoCall) {
                        Future.delayed(const Duration(seconds: 1), () {
                          CommunicationService().callSosNumber();
                        });
                      }
                    }
                    BleData.panicTimer = null;
                  });
                } else if (value.length > 4 && value[4] == 0) {
                  // Botón soltado
                  print("Botón HolyIoT soltado");
                  if (BleData.panicTimer != null && BleData.panicTimer!.isActive) {
                    BleData.panicTimer!.cancel();
                  }
                  BleData.buttonPressed = false;
                  BleData.panicTimer = null;
                }
                
                // Verificar si es una notificación de botón (Comando 16: F3 15 F3 LEN XX)
                if (value.length >= 5 && 
                    value[0] == 0xF3 && 
                    value[1] == 0x15 && 
                    value[2] == 0xF3) {
                  
                  int buttonState = value[4];
                  
                  if (buttonState == 1 && !BleData.buttonPressed && BleData.panicTimer == null) {
                    triggerSosAlert(device, onSosActivated);
                  } else if (buttonState == 0) {
                    // Botón soltado
                    print("Botón HolyIoT soltado (protocolo)");
                    if (BleData.panicTimer != null && BleData.panicTimer!.isActive) {
                      BleData.panicTimer!.cancel();
                    }
                    BleData.buttonPressed = false;
                    BleData.panicTimer = null;
                  }
                }
                
                // Verificar si es una notificación de batería (Comando 17: F3 16 F3 LEN XX)
                if (value.length >= 5 && 
                     value[0] == 0xF3 && 
                     value[1] == 0x16 && 
                     value[2] == 0xF3) {
                  
                  int len = value[3];
                  if (len >= 1) {
                    int batteryLevel = value[4];
                    print("Nivel de batería HolyIoT recibido: $batteryLevel%");
                    BleData.update(newBatteryLevel: batteryLevel);
                  }
                }
              }
            });
          }
        }
      }
    }
    
    if (!found) {
      throw Exception("Servicio HolyIoT no encontrado");
    }
  }
  
  // Configurar notificaciones para dispositivos Honycomm
  static Future<void> setupHonycommNotifications(BluetoothDevice device, Function onSosActivated) async {
    print("Configurando notificaciones para Honycomm: ${device.remoteId}");
    
    // Para Honycomm, necesitamos buscar servicios que puedan proporcionar notificaciones
    List<BluetoothService> services = await device.discoverServices();
    bool found = false;
    
    // Imprime información detallada de todos los servicios y características
    print("🔍 Servicios encontrados para Honycomm:");
    for (var service in services) {
      print("Servicio: ${service.uuid}");
      for (var characteristic in service.characteristics) {
        String props = "";
        if (characteristic.properties.read) props += "READ ";
        if (characteristic.properties.write) props += "WRITE ";
        if (characteristic.properties.writeWithoutResponse) props += "WRITE_NO_RESP ";
        if (characteristic.properties.notify) props += "NOTIFY ";
        if (characteristic.properties.indicate) props += "INDICATE ";
        
        print("  Característica: ${characteristic.uuid} - Props: $props");
      }
    }
    
    // Primero, intentamos suscribirnos a TODAS las características que tienen notificación
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify || characteristic.properties.indicate) {
          print("✅ Habilitando notificaciones para característica: ${characteristic.uuid}");
          try {
            await characteristic.setNotifyValue(true);
            
            // Configurar listener para esta característica
            characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                print("📊 Datos recibidos de Honycomm (${characteristic.uuid}): $value");
                
                // Guardar datos para análisis histórico
                addToDataHistory(value);
                
                // Intentar detectar SOS y batería con varios métodos
                checkHonycommPatterns(value, device, onSosActivated);
                tryExtractBatteryLevel(value);
                
                // Verificar si es una notificación de botón usando el formato de la documentación
                if (value.length > 12) {
                  int statusByte = value[12];
                  print("📊 Byte de estado (byte 12): $statusByte, bits: ${statusByte.toRadixString(2).padLeft(8, '0')}");
                  
                  // Comprobar el bit 5 (posición 6 contando desde 1), que según la documentación indica SOS
                  bool isSosActive = (statusByte & 0x20) != 0;
                  
                  if (isSosActive) {
                    print("🚨 SOS DETECTADO en Honycomm por bit 5 del byte 12");
                    triggerSosAlert(device, onSosActivated);
                  }
                }
              }
            });
            
            found = true;
          } catch (e) {
            print("⚠️ Error al suscribirse a característica: $e");
          }
        }
      }
    }
    
    // Si no se pudo encontrar ninguna característica con notificación
    if (!found) {
      print("⚠️ No se encontraron características con notificación para Honycomm. Intentando leer características...");
      
      // Intento alternativo: leer todas las características legibles para ver qué datos contienen
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();
              print("📊 Datos leídos de característica ${characteristic.uuid}: $value");
              
              // Intentar detectar información sobre batería o botón
              tryExtractBatteryLevel(value);
            } catch (e) {
              print("⚠️ Error al leer característica: $e");
            }
          }
        }
      }
      
      throw Exception("No se encontraron características con notificación para Honycomm");
    }
  }
  
  // Método para escribir a una característica específica para solicitar datos
  static Future<void> writeToCharacteristic(BluetoothDevice device, String serviceUuid, String characteristicUuid, List<int> data) async {
    print("Intentando escribir datos a característica: $characteristicUuid");
    
    try {
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(serviceUuid.toLowerCase())) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains(characteristicUuid.toLowerCase())) {
              if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
                await characteristic.write(data);
                print("✅ Datos escritos correctamente: $data");
                return;
              } else {
                print("⚠️ La característica no tiene permisos de escritura");
              }
            }
          }
        }
      }
      
      print("⚠️ No se encontró el servicio o característica especificados");
    } catch (e) {
      print("❌ Error al escribir datos: $e");
    }
  }
  
  // Función para leer el nivel de batería según el tipo de dispositivo
  static Future<int> readBatteryLevel(BluetoothDevice device, int deviceType) async {
    try {
      if (deviceType == BLE_DEVICE_HOLYIOT) {
        return await readHolyIoTBattery(device);
      } else if (deviceType == BLE_DEVICE_HONYCOMM) {
        return await readHonycommBattery(device);
      } else {
        // Si no sabemos el tipo, intentamos ambos métodos
        try {
          int batteryLevel = await readHolyIoTBattery(device);
          if (batteryLevel > 0) {
            return batteryLevel;
          }
        } catch (e) {
          print("Error al leer batería HolyIoT: $e");
        }
        
        try {
          int batteryLevel = await readHonycommBattery(device);
          if (batteryLevel > 0) {
            return batteryLevel;
          }
        } catch (e) {
          print("Error al leer batería Honycomm: $e");
        }
        
        // Si ninguno funciona, intentamos métodos más genéricos
        return await readGenericBattery(device);
      }
    } catch (e) {
      print("❌ Error general al leer nivel de batería: $e");
      return 0;
    }
  }
  
  // Leer batería para dispositivos HolyIoT
  static Future<int> readHolyIoTBattery(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(HOLYIOT_SERVICE_UUID.toLowerCase())) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains(HOLYIOT_WRITE_UUID.toLowerCase()) &&
                (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
              // Enviar comando F3 16 F3 para solicitar nivel de batería
              await characteristic.write([0xF3, 0x16, 0xF3]);
              print("Comando de batería HolyIoT enviado: F3 16 F3");
              
              // La respuesta se recibirá en la característica de notificación
              // que ya debería estar configurada para ser monitoreada
              
              // Esperar un tiempo razonable para que llegue la respuesta
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Devolver valor de batería actualizado desde BleData
              return BleData.batteryLevel;
            }
          }
        }
      }
      
      return 0;
    } catch (e) {
      print("Error al leer batería HolyIoT: $e");
      return 0;
    }
  }
  
  // Leer batería para dispositivos Honycomm
  static Future<int> readHonycommBattery(BluetoothDevice device) async {
    try {
      print("Intentando leer batería para Honycomm...");
      
      // Método 1: Intentar leer directamente la característica de batería si existe
      // (primero buscamos una característica que contenga "battery" en su UUID)
      List<BluetoothService> services = await device.discoverServices();
      
      // Intentar encontrar alguna característica que pueda contener información de batería
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          String charUuid = characteristic.uuid.toString().toLowerCase();
          
          // Verificar características que podrían contener batería
          if (charUuid.contains("180f") || charUuid.contains("batt") || 
              charUuid.contains("2a19") || charUuid.contains("battery")) {
            if (characteristic.properties.read) {
              try {
                List<int> value = await characteristic.read();
                print("📊 Datos leídos de característica de batería potencial: $value");
                
                if (value.isNotEmpty) {
                  // Suponiendo que el primer byte podría ser el nivel de batería (0-100)
                  int batteryLevel = value[0];
                  if (batteryLevel >= 0 && batteryLevel <= 100) {
                    print("Nivel de batería Honycomm: $batteryLevel%");
                    BleData.update(newBatteryLevel: batteryLevel);
                    return batteryLevel;
                  }
                }
              } catch (e) {
                print("Error al leer característica de batería: $e");
              }
            }
          }
        }
      }
      
      // Método 2: Intentar enviar algún comando para solicitar batería
      // Probar con diferentes servicios/características para escribir comandos
      
      // Comando genérico para solicitar batería (valor 0x10 podría ser un comando común)
      List<int> batteryCommand = [0x10];
      
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            try {
              print("Enviando comando de batería a ${characteristic.uuid}");
              await characteristic.write(batteryCommand, withoutResponse: characteristic.properties.writeWithoutResponse);
              
              // Esperar un tiempo para que llegue la respuesta
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Cualquier valor recibido se procesará en los listeners configurados
            } catch (e) {
              // Ignorar errores, seguir intentando con otras características
            }
          }
        }
      }
      
      // Si no hemos podido leer la batería de manera directa,
      // usamos el último valor conocido desde los datos de notificación
      if (BleData.batteryLevel > 0) {
        return BleData.batteryLevel;
      }
      
      return 0;
    } catch (e) {
      print("Error al leer batería Honycomm: $e");
      return 0;
    }
  }
  
  // Método genérico para leer batería
  static Future<int> readGenericBattery(BluetoothDevice device) async {
    try {
      // Método 1: Buscar el servicio estándar de batería
      // UUID estándar para servicio de batería: 0x180F 
      // UUID estándar para característica de nivel de batería: 0x2A19
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains("180f")) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains("2a19")) {
              if (characteristic.properties.read) {
                List<int> value = await characteristic.read();
                if (value.isNotEmpty) {
                  int batteryLevel = value[0];
                  print("Nivel de batería leído del servicio estándar: $batteryLevel%");
                  BleData.update(newBatteryLevel: batteryLevel);
                  return batteryLevel;
                }
              }
            }
          }
        }
      }
      
      // Método 2: Probar comandos genéricos en cualquier característica escribible
      
      // Lista de posibles comandos para solicitar batería
      List<List<int>> batteryCommands = [
        [0x10],                    // Comando genérico simple
        [0xF3, 0x16, 0xF3],        // Comando estilo HolyIoT
        [0xAA, 0x10],              // Otro posible formato
        [0x03, 0x10, 0x01]         // Otro posible formato
      ];
      
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            for (var cmd in batteryCommands) {
              try {
                print("Probando comando de batería $cmd en ${characteristic.uuid}");
                await characteristic.write(cmd, withoutResponse: characteristic.properties.writeWithoutResponse);
                
                // Esperar un tiempo para que llegue la respuesta
                await Future.delayed(const Duration(milliseconds: 300));
              } catch (e) {
                // Ignorar errores, seguir intentando
              }
            }
          }
        }
      }
      
      // Método 3: Intentar leer todas las características legibles
      // para buscar valores que podrían ser niveles de batería
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            try {
              List<int> value = await characteristic.read();
              
              if (value.isNotEmpty) {
                // Buscar valores entre 0-100 que podrían ser porcentajes de batería
                for (int i = 0; i < value.length; i++) {
                  int byte = value[i];
                  if (byte >= 20 && byte <= 100) { // Comenzar desde 20 para reducir falsos positivos
                    print("Posible nivel de batería encontrado en ${characteristic.uuid}: $byte%");
                    // No actualizamos directamente para evitar falsos positivos
                  }
                }
              }
            } catch (e) {
              // Ignorar errores
            }
          }
        }
      }
      
      return 0;
    } catch (e) {
      print("Error en readGenericBattery: $e");
      return 0;
    }
  }

  static Future<bool> configureHonycommDevice(BluetoothDevice device, String password) async {
  print("Intentando configurar dispositivo Honycomm: ${device.remoteId}");
  
  try {
    // Descubrir servicios del dispositivo
    List<BluetoothService> services = await device.discoverServices();
    
    // Imprimir servicios para depuración
    print("Servicios encontrados:");
    for (var service in services) {
      print("UUID: ${service.uuid}");
      for (var characteristic in service.characteristics) {
        String props = "";
        if (characteristic.properties.read) props += "READ ";
        if (characteristic.properties.write) props += "WRITE ";
        if (characteristic.properties.writeWithoutResponse) props += "WRITE_NO_RESP ";
        if (characteristic.properties.notify) props += "NOTIFY ";
        if (characteristic.properties.indicate) props += "INDICATE ";
        
        print("  - Char: ${characteristic.uuid} - Props: $props");
      }
    }
    
    // Buscar características escribibles donde podríamos enviar comandos
    bool passwordSent = false;
    bool modeChanged = false;
    
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          print("Intentando usar característica: ${characteristic.uuid} para enviar comandos");
          
          // 1. Enviar contraseña
          // Convertir la contraseña a bytes (suponiendo que es "1234" o similar)
          List<int> passwordBytes = [];
          
          // Si la contraseña es numérica, formatearla como bytes
          if (RegExp(r'^\d+$').hasMatch(password)) {
            // Para contraseñas numéricas, podemos probar diferentes formatos
            
            // Formato 1: Comando específico + contraseña como ASCII
            try {
              // Comando para autenticación (basado en el protocolo general)
              List<int> authCmd1 = [0xF3, 0x00, 0xF3, 0x06]; // Comando + longitud (6 bytes)
              
              // Añadir la contraseña como bytes ASCII
              for (int i = 0; i < password.length; i++) {
                authCmd1.add(password.codeUnitAt(i));
              }
              
              // Rellenar con ceros si es necesario
              while (authCmd1.length < 10) { // Comando(3) + Longitud(1) + Password(6)
                authCmd1.add(0x00);
              }
              
              print("Enviando comando de autenticación 1: $authCmd1");
              await characteristic.write(authCmd1, withoutResponse: characteristic.properties.writeWithoutResponse);
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Intentar leer respuesta si es posible
              if (characteristic.properties.read) {
                try {
                  List<int> response = await characteristic.read();
                  print("Respuesta: $response");
                  
                  // Verificar si la respuesta indica éxito (F3 00 F3 00)
                  if (response.length >= 4 && 
                      response[0] == 0xF3 && 
                      response[1] == 0x00 && 
                      response[2] == 0xF3 && 
                      response[3] == 0x00) {
                    print("✅ Autenticación exitosa!");
                    passwordSent = true;
                  }
                } catch (e) {
                  print("Error al leer respuesta: $e");
                }
              }
              
              // Formato 2: Contraseña como bytes directamente
              if (!passwordSent) {
                List<int> authCmd2 = [];
                for (int i = 0; i < password.length; i++) {
                  // Convertir cada dígito a su valor numérico
                  authCmd2.add(int.parse(password[i]));
                }
                
                print("Enviando comando de autenticación 2: $authCmd2");
                await characteristic.write(authCmd2, withoutResponse: characteristic.properties.writeWithoutResponse);
                await Future.delayed(const Duration(milliseconds: 500));
              }
              
            } catch (e) {
              print("Error al enviar contraseña: $e");
            }
          } else {
            // Para contraseñas alfanuméricas
            for (int i = 0; i < password.length; i++) {
              passwordBytes.add(password.codeUnitAt(i));
            }
            
            try {
              print("Enviando contraseña: $passwordBytes");
              await characteristic.write(passwordBytes, withoutResponse: characteristic.properties.writeWithoutResponse);
              await Future.delayed(const Duration(milliseconds: 500));
            } catch (e) {
              print("Error al enviar contraseña: $e");
            }
          }
          
          // 2. Cambiar modo de operación a conectable
          try {
            // Según la documentación, necesitamos cambiar el modo a conectable
            // Bit 4 del byte 12 donde 0 = modo conectable, 1 = modo no-conectable
            
            // Comando para cambiar modo (basado en inferencia del protocolo)
            // Nota: Este es un comando hipotético basado en la información disponible
            List<int> modeCmd = [0xF3, 0x0C, 0xF3, 0x01, 0x00]; // Byte 12, bit 4 = 0 (conectable)
            
            print("Enviando comando para cambiar modo: $modeCmd");
            await characteristic.write(modeCmd, withoutResponse: characteristic.properties.writeWithoutResponse);
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Intentar un comando alternativo si el primero no funciona
            List<int> alternateModeCmd = [0xBB, 0x04, 0x00]; // Comando arbitrario para cambiar modo
            
            print("Enviando comando alternativo: $alternateModeCmd");
            await characteristic.write(alternateModeCmd, withoutResponse: characteristic.properties.writeWithoutResponse);
            
            // Marcar como potencialmente exitoso
            modeChanged = true;
            
          } catch (e) {
            print("Error al cambiar modo: $e");
          }
          
          // 3. Cambiar intervalo de broadcast a algo razonable (por ejemplo, 1 segundo)
          try {
            // Según la documentación, comando para cambiar intervalo de broadcast
            List<int> intervalCmd = [0xF3, 0x07, 0xF3, 0x01, 0x04]; // Nivel 4 (valor intermedio)
            
            print("Enviando comando para cambiar intervalo: $intervalCmd");
            await characteristic.write(intervalCmd, withoutResponse: characteristic.properties.writeWithoutResponse);
            
          } catch (e) {
            print("Error al cambiar intervalo: $e");
          }
        }
      }
    }
    
    return passwordSent || modeChanged;
    
  } catch (e) {
    print("Error general al configurar Honycomm: $e");
    return false;
  }
}

// Añade este método al final de la clase BleDeviceHandler

// Método para mostrar un diálogo de configuración
static Future<void> showHonycommConfigDialog(BuildContext context, BluetoothDevice device) async {
  TextEditingController passwordController = TextEditingController(text: "1234"); // Password por defecto
  
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Configurar Honycomm"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Este dispositivo Honycomm está en modo de seguridad. Ingresa la contraseña para configurarlo y hacerlo conectable permanentemente.",
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: "Contraseña",
              hintText: "Por defecto: 1234",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            
            // Mostrar indicador de progreso
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Configurando dispositivo..."),
                  ],
                ),
              ),
            );
            
            try {
              bool success = await configureHonycommDevice(device, passwordController.text);
              
              // Cerrar diálogo de progreso
              Navigator.pop(context);
              
              // Mostrar resultado
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(success ? "Configuración Exitosa" : "Error"),
                  content: Text(
                    success 
                      ? "El dispositivo ha sido configurado. Debería estar visible y conectable permanentemente ahora."
                      : "No se pudo configurar el dispositivo. Verifica la contraseña e intenta nuevamente."
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            } catch (e) {
              // Cerrar diálogo de progreso
              Navigator.pop(context);
              
              // Mostrar error
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Error"),
                  content: Text("Error al configurar: $e"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            }
          },
          child: const Text("Configurar"),
        ),
      ],
    ),
  );
}

}
*/