import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class IOSPermissionGuidePage extends StatefulWidget {
  const IOSPermissionGuidePage({super.key});

  @override
  IOSPermissionGuidePageState createState() => IOSPermissionGuidePageState();
}

class IOSPermissionGuidePageState extends State<IOSPermissionGuidePage> {
  bool locationAlwaysGranted = false;
  bool bluetoothGranted = false;
  bool notificationsGranted = false;
  bool isChecking = false;

  @override
  void initState() {
    super.initState();
    checkPermissions();
    
    // ✅ AGREGAR: Verificar permisos periódicamente para updates en tiempo real
    Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted) {
        checkPermissions();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> checkPermissions() async {
    if (!mounted) return;
    
    setState(() => isChecking = true);
    
    try {
      bool newLocationAlwaysGranted = await Permission.locationAlways.isGranted;
      bool newBluetoothGranted = await Permission.bluetooth.isGranted;
      bool newNotificationsGranted = await Permission.notification.isGranted;
      
      // ✅ Solo actualizar estado si hay cambios para evitar rebuilds innecesarios
      if (newLocationAlwaysGranted != locationAlwaysGranted ||
          newBluetoothGranted != bluetoothGranted ||
          newNotificationsGranted != notificationsGranted) {
        
        print("🔄 Permisos actualizados:");
        print("   📍 Ubicación: $locationAlwaysGranted → $newLocationAlwaysGranted");
        print("   🔵 Bluetooth: $bluetoothGranted → $newBluetoothGranted");
        print("   🔔 Notificaciones: $notificationsGranted → $newNotificationsGranted");
        
        if (mounted) {
          setState(() {
            locationAlwaysGranted = newLocationAlwaysGranted;
            bluetoothGranted = newBluetoothGranted;
            notificationsGranted = newNotificationsGranted;
          });
        }
      }
    } catch (e) {
      print("❌ Error verificando permisos: $e");
    }
    
    if (mounted) {
      setState(() => isChecking = false);
    }
  }

Future<void> requestLocationAlways() async {
  setState(() => isChecking = true);
  
  try {
    print("📍 iOS: Verificando permisos de ubicación...");
    
    PermissionStatus currentStatus = await Permission.locationAlways.status;
    print("📍 Estado actual: $currentStatus");
    
    if (currentStatus.isDenied) {
      // Primera vez - intentar solicitar
      bool shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("📍 Configurar Ubicación"),
          content: const Text(
            "Para emergencias 24/7, necesitamos ubicación 'Siempre'.\n\n"
            "1. Presiona 'Ir a Settings'\n"
            "2. Busca esta app en la lista\n"
            "3. Selecciona 'Ubicación'\n"
            "4. Elige 'Siempre'\n\n"
            "¿Quieres ir a Settings ahora?"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Más tarde"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Ir a Settings", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ?? false;

      if (shouldRequest) {
        // Intentar solicitar primero
        await Permission.locationWhenInUse.request();
        await Permission.locationAlways.request();
        
        // Si sigue denegado, ir a Settings
        PermissionStatus newStatus = await Permission.locationAlways.status;
        if (!newStatus.isGranted) {
          await openAppSettings();
        }
      }
    } else if (currentStatus.isPermanentlyDenied) {
      // Ya denegado permanentemente - ir directo a Settings
      bool shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("📍 Ubicación Denegada"),
          content: const Text(
            "Los permisos están denegados.\n\n"
            "Para habilitarlos:\n"
            "1. Ve a Settings del iPad\n"
            "2. Busca esta app\n"
            "3. Toca 'Ubicación'\n"
            "4. Selecciona 'Siempre'\n\n"
            "¿Abrir Settings ahora?"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Más tarde"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Abrir Settings", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ?? false;

      if (shouldOpenSettings) {
        await openAppSettings();
      }
    }
    
    // ✅ IMPORTANTE: Forzar actualización después de cambios
    await Future.delayed(Duration(seconds: 1));
    await checkPermissions();
    
  } catch (e) {
    print("❌ Error con permisos de ubicación: $e");
  }
  
  setState(() => isChecking = false);
}

  
Future<void> requestBluetooth() async {
  setState(() => isChecking = true);
  
  try {
    bool shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🔵 Configurar Bluetooth"),
        content: const Text(
          "Para conectar con tu dispositivo SOS:\n\n"
          "1. Ve a Settings del iPad\n"
          "2. Busca 'Privacidad y Seguridad'\n"
          "3. Busca esta app en la lista\n"
          "4. Activa 'Bluetooth'\n\n"
          "¿Abrir Settings ahora?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Más tarde"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Abrir Settings", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldOpenSettings) {
      await openAppSettings();
    }
    
    await checkPermissions();
    
  } catch (e) {
    print("❌ Error con permisos de Bluetooth: $e");
  }
  
  setState(() => isChecking = false);
}


 Future<void> requestNotifications() async {
  setState(() => isChecking = true);
  
  try {
    bool shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🔔 Configurar Notificaciones"),
        content: const Text(
          "Para alertas de emergencia:\n\n"
          "1. Ve a Settings del iPad\n"
          "2. Busca 'Notificaciones'\n"
          "3. Busca esta app en la lista\n"
          "4. Activa 'Permitir notificaciones'\n\n"
          "¿Abrir Settings ahora?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Más tarde"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Abrir Settings", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (shouldOpenSettings) {
      await openAppSettings();
    }
    
    await checkPermissions();
    
  } catch (e) {
    print("❌ Error con permisos de notificaciones: $e");
  }
  
  setState(() => isChecking = false);
}

@override
Widget build(BuildContext context) {
  bool allPermissionsGranted = locationAlwaysGranted && bluetoothGranted && notificationsGranted;
  
  return Scaffold(
    appBar: AppBar(
      title: const Text("Permisos para App SOS", style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.green, // ✅ CAMBIO: Verde consistente
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ CAMBIO: Mostrar encuadre apropiado según estado
            if (!allPermissionsGranted) ...[
              // Mostrar encuadre de permisos pendientes
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.orange,
                      size: 40,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Permisos pendientes",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "iOS necesita configuraciones específicas",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Mostrar encuadre de permisos completados
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 40,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "¡Permisos configurados correctamente!",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tu app SOS funcionará de manera óptima",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Información específica iOS
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50, // ✅ CAMBIO: Verde suave
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200), // ✅ CAMBIO: Borde verde
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.green.shade700, size: 16), // ✅ CAMBIO: Verde
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Es de suma importancia activar todos los permisos para el buen funcionamiento de esta APP",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green.shade700, // ✅ CAMBIO: Verde
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Lista de permisos específicos iOS
            if (isChecking)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildIOSPermissionTile(
                title: "Ubicación Siempre",
                description: "Para emergencias 24/7",
                extraText: "Es muy importante que seleccione en Settings (Configuración) de su móvil la opción \"Siempre\" (Always en inglés)",
                icon: Icons.location_on,
                isGranted: locationAlwaysGranted,
                onTap: locationAlwaysGranted ? null : requestLocationAlways,
                priority: "Crítico",
              ),
              
              const SizedBox(height: 12),
              
              _buildIOSPermissionTile(
                title: "Bluetooth",
                description: "Conexión automática con dispositivo SOS",
                icon: Icons.bluetooth,
                isGranted: bluetoothGranted,
                onTap: bluetoothGranted ? null : requestBluetooth,
                priority: "Esencial",
              ),
              
              const SizedBox(height: 12),
              
              _buildIOSPermissionTile(
                title: "Notificaciones",
                description: "Alertas críticas de emergencia",
                icon: Icons.notifications,
                isGranted: notificationsGranted,
                onTap: notificationsGranted ? null : requestNotifications,
                priority: "Importante",
              ),
            ],
            
            const SizedBox(height: 20),
            
            // ✅ CAMBIO: Botón dinámico según estado de permisos
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: allPermissionsGranted ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  allPermissionsGranted ? "✅ Permisos Otorgados" : "Configurar más tarde", // ✅ CAMBIO: Texto dinámico
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            if (!allPermissionsGranted) ...[
              const SizedBox(height: 8),
              Text(
                "💡 iOS funciona mejor con todas las configuraciones",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildIOSPermissionTile({
  required String title,
  required String description,
  String? extraText, // ✅ NUEVO: Parámetro opcional para texto adicional
  required IconData icon,
  required bool isGranted,
  required String priority,
  VoidCallback? onTap,
}) {
  Color priorityColor = priority == "Crítico" 
      ? Colors.red 
      : priority == "Esencial" 
          ? Colors.orange 
          : Colors.blue;
  
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Icon(
        icon,
        color: isGranted ? Colors.green : priorityColor,
        size: 28,
      ),
      title: Column( // ✅ CAMBIO: Envolver en Column para agregar texto adicional
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: priorityColor.withOpacity(0.3)),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          // ✅ NUEVO: Texto adicional si se proporciona
          if (extraText != null) ...[
            const SizedBox(height: 4),
            Text(
              extraText,
              style: const TextStyle(
                fontSize: 14, // ✅ Mismo tamaño que el título
                color: Colors.blue, // ✅ Color azul
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      trailing: isGranted
        ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
        : TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              side: const BorderSide(color: Colors.green, width: 1), // ✅ CAMBIO: Borde verde
            ),
            child: const Text(
              "Configurar", 
              style: TextStyle(fontSize: 12, color: Colors.black), // ✅ CAMBIO: Texto negro
            ),
          ),
    ),
  );
}
}