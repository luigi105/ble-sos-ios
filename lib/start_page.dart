import 'package:flutter/material.dart';
import 'ble_data.dart';
import 'imei_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});
  
  @override
  StartPageState createState() => StartPageState();
}

class StartPageState extends State<StartPage> {
  int? selectedOption; // 1 para "Sí", 2 para "No"
  
  // Manejar la selección de los checkboxes
  void updateSelection(int value) {
    setState(() {
      selectedOption = value;
    });
  }
  
  // Manejar el botón de "Siguiente"
  void onNextPressed() async {
    if (selectedOption != null) {
      await BleData.setConBoton(selectedOption!);
      if (selectedOption == 2) {
        await BleData.clearMacAddress();
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ImeiPage(),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Obtener información sobre la pantalla
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    
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
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.08,
            vertical: size.height * 0.03,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Espacio superior adaptativo
              SizedBox(height: size.height * 0.1),
              
              // Texto principal
              const Text(
                "¿Vas a usar un botón Bluetooth con la app?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Espacio adaptativo
              SizedBox(height: size.height * 0.04),
              
              // Checkboxes para selección
              // Ajustar layout según la orientación
              orientation == Orientation.portrait ? 
              // Layout vertical para modo retrato
              Column(
                children: [
                  _buildCheckboxOption(1, "Sí"),
                  SizedBox(height: size.height * 0.02),
                  _buildCheckboxOption(2, "No"),
                ],
              ) : 
              // Layout horizontal para modo paisaje
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCheckboxOption(1, "Sí"),
                  SizedBox(width: size.width * 0.1),
                  _buildCheckboxOption(2, "No"),
                ],
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
                    onPressed: selectedOption != null ? onNextPressed : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.04,
                        vertical: size.height * 0.015
                      ),
                      side: const BorderSide(color: Colors.green, width: 2),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      "Siguiente",
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
              ),
              
              // Espacio inferior
              SizedBox(height: size.height * 0.1),
            ],
          ),
        ),
      ),
    );
  }
  
  // Widget para construir una opción de checkbox
  Widget _buildCheckboxOption(int value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: selectedOption == value,
          onChanged: (isChecked) => updateSelection(value),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}