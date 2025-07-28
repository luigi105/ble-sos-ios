import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'coms.dart';
import 'dart:async';
import 'ble_data.dart';
import 'dart:io';

bool buttonPressed = false;
Timer? panicTimer;

// Reemplaza la función connectToDevice en connect.dart con esta versión mejorada
// Función corregida para connect.dart
void connectToDevice(BluetoothDevice device, BuildContext context, Function discoverServicesCallback, Function triggerUpdateTimerCallback, Function onSosActivated) async {
  try {
    print("Intentando conectar con el dispositivo: ${device.remoteId}");

        // ✅ ESTRATEGIA ESPECÍFICA POR PLATAFORMA
    if (Platform.isIOS) {
      // iOS: Usar autoConnect para reconexión automática
      await device.connect(
        autoConnect: true, // Crítico para iOS
        timeout: const Duration(seconds: 30),
      );
    } else {
      // Android: Tu lógica existente
      await device.connect(
        timeout: const Duration(seconds: 15),
      );
    }
    
    // Verificar el estado actual de conexión
    BluetoothConnectionState state = await device.connectionState.first;

    // Si ya está conectado, no hacer nada más
    if (state == BluetoothConnectionState.connected) {
      print("Dispositivo ya conectado: ${device.remoteId}");
      BleData.update(
        newMacAddress: device.remoteId.toString(),
        connectionStatus: true,
      );
      discoverServicesCallback(device, context, onSosActivated);
      triggerUpdateTimerCallback();
      return;
    }

    // Detener cualquier escaneo activo
    try {
      await FlutterBluePlus.stopScan();
      print("Escaneo detenido para iniciar conexión.");
    } catch (e) {
      print("Advertencia al detener escaneo: $e");
    }

    // Cancelar cualquier suscripción anterior para evitar fugas de memoria
    BleData.cancelConnectionSubscription();

    // Intentar conectar con el dispositivo
    // IMPORTANTE: Quitar el autoConnect y usar timeout más largo
    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        // autoConnect: true <- ELIMINADO para evitar conflicto
      );
      print("Conexión inicial exitosa");
    } catch (e) {
      print("Error en conexión inicial: $e");
      // Intentar nuevamente sin autoConnect
      try {
        await device.connect(timeout: const Duration(seconds: 30));
      } catch (secondError) {
        print("Error en segundo intento de conexión: $secondError");
        return; // Si falla dos veces, salir
      }
    }

    // Configurar un listener permanente para el estado de conexión
    StreamSubscription<BluetoothConnectionState> connectionStateSubscription;
    connectionStateSubscription = device.connectionState.listen((newState) {
      print("Estado del dispositivo ${device.remoteId}: $newState");
      
      if (newState == BluetoothConnectionState.connected) {
        print("✅ Conexión exitosa: ${device.remoteId}");
        BleData.update(
          newMacAddress: device.remoteId.toString(),
          connectionStatus: true,
        );
        // Guardar el estado de conexión para recuperación después de reinicio
        BleData.saveConnectionState(true);
        
        // Descubrir servicios y configurar notificaciones
        discoverServicesCallback(device, context, onSosActivated);
        
        // Iniciar actualización periódica de datos
        triggerUpdateTimerCallback();
      } 
      else if (newState == BluetoothConnectionState.disconnected) {
        print("❌ Dispositivo desconectado: ${device.remoteId}");
        BleData.update(
          newMacAddress: device.remoteId.toString(),
          connectionStatus: false,
        );
        BleData.saveConnectionState(false);
        
        // Intentar reconectar automáticamente después de una desconexión
        Future.delayed(const Duration(seconds: 8), () {
          if (!BleData.isConnected) {
            print("🔄 Intentando reconexión automática después de desconexión...");
            try {
              device.connect(timeout: const Duration(seconds: 30)).catchError((e) {
                print("Error en reconexión automática: $e");
              });
            } catch (e) {
              print("Excepción en reconexión automática: $e");
            }
          }
        });
      }
    });
    
    // Almacenar la suscripción para poder cancelarla cuando sea necesario
    BleData.connectionSubscription = connectionStateSubscription;
    
  } catch (e) {
    print("Error general al intentar conectar con el dispositivo: $e");

    // Verificar si el error es el código 133 (ANDROID_SPECIFIC_ERROR)
    // Solo para Android
    if (Platform.isAndroid && e.toString().contains("133")) {
      promptToToggleBluetooth();
    }
  }
}

// Mostrar mensaje al usuario para que reinicie manualmente el Bluetooth
void promptToToggleBluetooth() {
  print("No se puede desactivar Bluetooth automáticamente. Solicita al usuario que lo reinicie manualmente.");
  // Puedes mostrar un diálogo visual
}



void discoverServices(BluetoothDevice device, BuildContext context, Function onSosActivated ) async {
  try {
    print("Descubriendo servicios del dispositivo: ${device.remoteId}");
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      if (service.uuid.toString() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e') {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                print("Valor recibido: $value");

                if (value[4] == 1 && !buttonPressed && panicTimer == null) {
                  buttonPressed = true;
                  panicTimer = Timer(const Duration(seconds: 3), () {
                    if (buttonPressed) {
                      print("¡Botón SOS presionado! Generando alerta...");
                      
                      // 🔊 Reproducir sonido de alerta
                      if (BleData.sosSoundEnabled) {
                       CommunicationService().playSosSound();
                        }

                       // 🔹 Intentamos traer la app al frente
                      CommunicationService().bringToForeground();  

                       onSosActivated(); // ✅ Llamamos la función para actualizar la UI

                      // 📌 Enviar alerta SOS
                      CommunicationService().sendSosAlert(
                    //    BleData.deviceId,           // ID único del celular
                        device.remoteId.toString(), // MAC address del dispositivo BLE
                      );
                      showPanicAlert(context, device.remoteId.toString());
                      // 📞 Llamada automática si está activada en la configuración
                      if (BleData.autoCall) {
                        Future.delayed(const Duration(seconds: 1), () {
                          CommunicationService().callSosNumber();
                        });
                      }
                    }
                    panicTimer = null;
                  });
                } else if (value[4] == 0) {
                  // Botón soltado
                  print("Botón soltado");
                  if (panicTimer != null && panicTimer!.isActive) {
                    panicTimer!.cancel();
                  }
                  buttonPressed = false;
                  panicTimer = null;
                }
              }
            });
          }
        }
      }
    }
  } catch (e) {
    print("Error en discoverServices: $e");
  }
}



void showPanicAlert(BuildContext context, String bleMacAddress) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("¡Alerta de Pánico!"),
        content: Text("Botón de pánico presionado en el dispositivo: $bleMacAddress"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cerrar"),
          ),
        ],
      );
    },
  );
}