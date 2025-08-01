import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/material.dart';
import 'coms.dart';
import 'dart:async';
import 'ble_data.dart';
import 'dart:io';

bool buttonPressed = false;
Timer? panicTimer;

String _lastBleError = "Ninguno";
String getLastBleError() => _lastBleError;

void connectToDevice(BluetoothDevice device, BuildContext context, Function discoverServicesCallback, Function triggerUpdateTimerCallback, Function onSosActivated) async {
  try {
    print("🔗 Intento de conexión con: ${device.remoteId}");

    if (Platform.isIOS) {
      print("🍎 === CONEXIÓN BLE iOS ===");
      
      try {
        await device.connect(
          autoConnect: true,
          timeout: const Duration(seconds: 45),
        );
        
        _lastBleError = "Conexión exitosa iOS";
        print("✅ iOS: Conexión inicial exitosa");
        
        BluetoothConnectionState currentState = await device.connectionState.first;
        print("🔍 iOS: Estado: $currentState");
        
        if (currentState == BluetoothConnectionState.connected) {
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
          
          await Future.delayed(Duration(seconds: 1));
          discoverServicesCallback(device, context, onSosActivated);
          triggerUpdateTimerCallback();
        }
        
      } catch (e) {
        _lastBleError = "Error conexión iOS: $e";
        print("❌ iOS: Error conexión: $e");
        
        try {
          await Future.delayed(Duration(seconds: 2));
          await device.connect(
            autoConnect: true,
            timeout: const Duration(seconds: 30),
          );
          _lastBleError = "Reconexión exitosa";
          print("✅ iOS: Reconexión exitosa");
        } catch (retryError) {
          _lastBleError = "Falló reconexión: $retryError";
          print("❌ iOS: Falló reconexión: $retryError");
        }
      }
      
      // Listener de estado
      device.connectionState.listen((state) {
        print("🔵 iOS Estado: $state");
        
        if (state == BluetoothConnectionState.connected) {
          _lastBleError = "Conectado y funcionando";
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: true,
          );
        } else {
          _lastBleError = "Desconectado: $state";
          BleData.update(
            newMacAddress: device.remoteId.toString(),
            connectionStatus: false,
          );
        }
      });
    }
    
  } catch (e) {
    _lastBleError = "Error general: $e";
    print("❌ Error general conectando: $e");
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