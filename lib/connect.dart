import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'coms.dart';
import 'dart:async';
import 'ble_data.dart';
import 'dart:io';

bool buttonPressed = false;
Timer? panicTimer;

void connectToDevice(BluetoothDevice device, BuildContext context, Function discoverServicesCallback, Function triggerUpdateTimerCallback, Function onSosActivated) async {
  try {
    print("🔗 Intentando conectar con el dispositivo: ${device.remoteId}");

    // ✅ ESTRATEGIA ESPECÍFICA POR PLATAFORMA
    if (Platform.isIOS) {
      print("🍎 === CONEXIÓN BLE PARA iOS ===");
      
      // ✅ iOS: Usar autoConnect para reconexión automática
      try {
        print("🔵 iOS: Conectando con autoConnect=true...");
        await device.connect(
          autoConnect: true, // ✅ CRÍTICO para iOS
          timeout: const Duration(seconds: 30),
        );
        print("✅ iOS: Conexión exitosa con autoConnect");
      } catch (e) {
        print("❌ iOS: Error en conexión inicial: $e");
        print("🔄 iOS: autoConnect seguirá intentando automáticamente");
        // En iOS, el autoConnect seguirá funcionando incluso si la conexión inicial falla
      }
      
      // ✅ CONFIGURAR listener para iOS
      device.connectionState.listen((state) {
        print("🔵 iOS BLE Estado: $state");
        
        if (state == BluetoothConnectionState.connected) {
          print("✅ iOS: BLE conectado - configurando servicios");
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
          BleData.saveConnectionState(true);
          
          // Descubrir servicios y configurar notificaciones
          discoverServicesCallback(device, context, onSosActivated);
          triggerUpdateTimerCallback();
          
        } else if (state == BluetoothConnectionState.disconnected) {
          print("⚠️ iOS: BLE desconectado - autoConnect manejará reconexión");
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: false,
          );
          BleData.saveConnectionState(false);
          
          // En iOS NO intentar reconexión manual - autoConnect lo maneja
        }
      });
      
    } else {
      // ✅ ANDROID: Tu lógica existente (sin cambios)
      
      // Verificar el estado actual de conexión
      BluetoothConnectionState state = await device.connectionState.first;

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

      // Cancelar cualquier suscripción anterior
      BleData.cancelConnectionSubscription();

      // Intentar conectar con el dispositivo
      try {
        await device.connect(
          timeout: const Duration(seconds: 15),
        );
        print("Conexión inicial exitosa");
      } catch (e) {
        print("Error en conexión inicial: $e");
        try {
          await device.connect(timeout: const Duration(seconds: 30));
        } catch (secondError) {
          print("Error en segundo intento de conexión: $secondError");
          return;
        }
      }

      // [Resto de tu lógica Android existente...]
    }
    
  } catch (e) {
    print("Error general al intentar conectar: $e");

    // Verificar si el error es el código 133 (solo Android)
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