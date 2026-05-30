import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const Map<String, List<String>> egyptianCarMarket = {
  'Hyundai': ['Verna', 'Elantra', 'Accent', 'Tucson', 'I10', 'Matrix', 'Bayon'],
  'Chevrolet': ['Optra', 'Aveo', 'Cruze', 'Captiva', 'Lanos', 'T-Series (D-Max)'],
  'Nissan': ['Sunny', 'Sentra', 'Qashqai', 'Juke'],
  'Toyota': ['Corolla', 'Yaris', 'Fortuner', 'C-HR', 'Hilux'],
  'Kia': ['Cerato', 'Sportage', 'Picanto', 'Rio', 'Carens', 'Xceed'],
  'Fiat': ['Tipo', '128', 'Shahin', 'Punto', '500'],
  'Renault': ['Logan', 'Sandero', 'Duster', 'Megane', 'Kadjar', 'Stepway'],
  'Chery': ['Tiggo 3', 'Tiggo 4', 'Tiggo 7', 'Tiggo 8', 'Arrizo 5', 'Envy'],
  'MG': ['MG 5', 'MG 6', 'ZS', 'RX5', 'HS'],
  'Mitsubishi': ['Lancer (Boma/Shark)', 'Eclipse Cross', 'Attrage', 'Mirage', 'Xpander'],
  'Suzuki': ['Maruti', 'Swift', 'Dzire', 'Ciaz', 'Ertiga', 'Vitara', 'Burgman'],
  'Peugeot': ['301', '508', '2008', '3008', '5008'],
  'Skoda': ['Octavia', 'Superb', 'Kodiaq', 'Karoq', 'Scala'],
  'Volkswagen': ['Passat', 'Golf', 'Tiguan', 'Jetta', 'Caddy'],
  'BMW': ['3 Series', '5 Series', 'X1', 'X3', 'X5', 'X6'],
  'Mercedes-Benz': ['C-Class', 'E-Class', 'A-Class', 'GLA', 'GLC', 'CLA'],
  'Geely': ['Emgrand 7', 'Coolray', 'Okavango', 'Geometry C'],
  'BYD': ['F3', 'L3'],
  'Opel': ['Astra', 'Insignia', 'Corsa', 'Grandland', 'Crossland'],
};

const List<String> carColorsList = [
  'White', 'Black', 'Silver', 'Grey', 'Red', 'Blue', 'Brown',
  'Beige', 'Gold', 'Green', 'Yellow', 'Orange',
];

class CarSelectionWidget extends StatefulWidget {
  final String? initialMake;
  final String? initialModel;
  final String? initialColor;
  final bool isDarkTheme;
  final Function(String? make, String? model, String? color) onChanged;

  const CarSelectionWidget({
    super.key,
    this.initialMake,
    this.initialModel,
    this.initialColor,
    this.isDarkTheme = false,
    required this.onChanged,
  });

  @override
  State<CarSelectionWidget> createState() => _CarSelectionWidgetState();
}

class _CarSelectionWidgetState extends State<CarSelectionWidget> {
  String? selectedMake;
  String? selectedModel;
  String? selectedColor;
  List<String> availableModels = [];

  @override
  void initState() {
    super.initState();
    selectedMake = widget.initialMake;
    selectedModel = widget.initialModel;
    selectedColor = widget.initialColor;
    if (selectedMake != null && egyptianCarMarket.containsKey(selectedMake)) {
      availableModels = egyptianCarMarket[selectedMake]!;
    }
  }

  InputDecoration _buildDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.greyText),
      filled: true,
      fillColor: widget.isDarkTheme ? Colors.white10 : AppColors.bgLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkTheme ? AppColors.white : AppColors.black;
    final dropdownColor = widget.isDarkTheme ? AppColors.navy : AppColors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: _buildDecoration('Car Make'),
          dropdownColor: dropdownColor,
          style: TextStyle(color: textColor),
          initialValue: egyptianCarMarket.containsKey(selectedMake) ? selectedMake : null,
          items: egyptianCarMarket.keys.map((String make) {
            return DropdownMenuItem<String>(
              value: make,
              child: Text(make),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              selectedMake = newValue;
              availableModels = egyptianCarMarket[newValue] ?? [];
              selectedModel = null; // Reset model when make changes
            });
            widget.onChanged(selectedMake, selectedModel, selectedColor);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: _buildDecoration('Car Model'),
          dropdownColor: dropdownColor,
          style: TextStyle(color: textColor),
          initialValue: availableModels.contains(selectedModel) ? selectedModel : null,
          items: selectedMake == null
              ? []
              : availableModels.map((String model) {
            return DropdownMenuItem<String>(
              value: model,
              child: Text(model),
            );
          }).toList(),
          onChanged: selectedMake == null
              ? null
              : (newValue) {
            setState(() {
              selectedModel = newValue;
            });
            widget.onChanged(selectedMake, selectedModel, selectedColor);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: _buildDecoration('Car Color'),
          dropdownColor: dropdownColor,
          style: TextStyle(color: textColor),
          initialValue: carColorsList.contains(selectedColor) ? selectedColor : null,
          items: carColorsList.map((String color) {
            return DropdownMenuItem<String>(
              value: color,
              child: Text(color),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              selectedColor = newValue;
            });
            widget.onChanged(selectedMake, selectedModel, selectedColor);
          },
        ),
      ],
    );
  }
}