import 'package:flutter/material.dart';
import 'ble_data.dart';
import 'coms.dart';
import 'main.dart';

class ImeiPage extends StatefulWidget {
  const ImeiPage({super.key});

  @override
  ImeiPageState createState() => ImeiPageState();
}

class ImeiPageState extends State<ImeiPage> {
  final TextEditingController imeiController = TextEditingController();
  bool isLoading = false;
  String errorMessage = "";

void onNextPressed() async {
  setState(() {
    isLoading = true;
    errorMessage = "";
  });

  String imei = imeiController.text.trim();

  if (imei.isEmpty) {
    setState(() {
      isLoading = false;
      errorMessage = "Por favor, ingrese un número IMEI.";
    });
    return;
  }

  await BleData.setImei(imei);
  print("📌 IMEI guardado: $imei");

  bool imeiExists = await CommunicationService().checkImei(imei);
  if (!imeiExists) {
    setState(() {
      isLoading = false;
      errorMessage = "❌ El IMEI ingresado no está registrado.";
    });
    return;
  }

  // ✅ MOSTRAR PROGRESO EN UI
  setState(() {
    errorMessage = "✅ IMEI válido. Obteniendo MAC Address...";
  });

  await CommunicationService().fetchMacAddress(imei);
  
  await Future.delayed(Duration(seconds: 2));
  
  // ✅ MOSTRAR RESULTADO EN UI
  setState(() {
    errorMessage = "✅ MAC Address obtenido: ${BleData.macAddress}";
  });
  
  await Future.delayed(Duration(seconds: 2));

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const BleScanPage()),
    (Route<dynamic> route) => false,
  );
}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Future.delayed(const Duration(milliseconds: 500), () {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      print("🚀 Reforzando estado a primer plano tras cambio de página.");
    });
  }

  @override
  Widget build(BuildContext context) {
    // Obtener información sobre la pantalla
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BLE SOS App',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Padding adaptativo basado en el porcentaje del ancho de la pantalla
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.08,
            vertical: size.height * 0.03,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Espacio superior adaptativo
              SizedBox(
                height: isKeyboardVisible 
                  ? size.height * 0.01 
                  : size.height * 0.1
              ),
              
              // Título
              const Text(
                "Ingresar Número IMEI",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Espacio adaptativo
              SizedBox(height: size.height * 0.04),

              // Campo de texto
              TextField(
                controller: imeiController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Ingrese el IMEI aquí",
                ),
              ),

              // Mensaje de error si existe
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: size.height * 0.02),
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      color: errorMessage.contains("✅") ? Colors.green : Colors.red,
                    ),
                  ),
                ),

              // Espacio adaptativo
              SizedBox(height: size.height * 0.04),

              // Botón con ancho adaptativo
              Center(
                child: Container(
                  width: orientation == Orientation.portrait 
                    ? size.width * 0.6 
                    : size.width * 0.3,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onNextPressed,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.04, 
                        vertical: size.height * 0.015
                      ),
                      side: const BorderSide(color: Colors.green, width: 2),
                      backgroundColor: Colors.white,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                            ),
                          )
                        : const Text(
                            "Siguiente",
                            style: TextStyle(fontSize: 18, color: Colors.black),
                          ),
                  ),
                ),
              ),
              
              // Espacio inferior para evitar que el teclado tape el botón
              SizedBox(
                height: isKeyboardVisible 
                  ? size.height * 0.3
                  : size.height * 0.1
              ),
            ],
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
    );
  }
}