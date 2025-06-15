import 'package:flutter/material.dart';
import '../models/weight_measurement.dart';
import '../services/weight_measurement_service.dart';

class AddMeasurementDialog {
 static Future<void> show(
   BuildContext context, {
   required WeightMeasurementService weightService,
   required List<WeightMeasurement> allMeasurements,
   required VoidCallback onSuccess,
   WeightMeasurement? existingMeasurement,
 }) async {
   final TextEditingController weightController = TextEditingController();
   DateTime selectedDate = existingMeasurement?.measurementDate ?? DateTime.now();
   bool isLoading = false;
   String? errorMessage;
   
   // Jeśli edycja towypełnia pole wagą
   if (existingMeasurement != null) {
     weightController.text = existingMeasurement.weightKg.toString();
   }

   return showDialog<void>(
     context: context,
     barrierDismissible: false,
     builder: (BuildContext context) {
       return StatefulBuilder(
         builder: (context, setState) {
           return AlertDialog(
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(16),
             ),
             title: Text(
               existingMeasurement != null ? 'Edytuj pomiar' : 'Dodaj pomiar',
               style: const TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: 20,
                 color: Colors.black87,
               ),
             ),
             content: SizedBox(
               width: double.maxFinite,
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // Pole daty
                   const Text(
                     'Data pomiaru',
                     style: TextStyle(
                       fontSize: 14,
                       fontWeight: FontWeight.w500,
                       color: Colors.black87,
                     ),
                   ),
                   const SizedBox(height: 8),
                   InkWell(
                     onTap: existingMeasurement != null ? null : () async {
                       final DateTime? picked = await showDatePicker(
                         context: context,
                         initialDate: selectedDate,
                         firstDate: DateTime(2020),
                         lastDate: DateTime.now(),
                       );
                       if (picked != null && picked != selectedDate) {
                         setState(() {
                           selectedDate = picked;
                         });
                       }
                     },
                     child: Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         border: Border.all(
                           color: existingMeasurement != null ? Colors.grey[400]! : Colors.grey[300]!
                         ),
                         borderRadius: BorderRadius.circular(12),
                         color: existingMeasurement != null ? Colors.grey[100] : null,
                       ),
                       child: Row(
                         children: [
                           Icon(
                             Icons.calendar_today,
                             color: existingMeasurement != null ? Colors.grey[600] : const Color(0xFFA69DF5),
                             size: 20,
                           ),
                           const SizedBox(width: 12),
                           Text(
                             '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.w500,
                               color: existingMeasurement != null ? Colors.grey[600] : Colors.black87,
                             ),
                           ),
                           if (existingMeasurement != null) ...[
                             const Spacer(),
                             Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                           ],
                         ],
                       ),
                     ),
                   ),
                   
                   const SizedBox(height: 20),
                   
                   // Pole wagi
                   const Text(
                     'Waga',
                     style: TextStyle(
                       fontSize: 14,
                       fontWeight: FontWeight.w500,
                       color: Colors.black87,
                     ),
                   ),
                   const SizedBox(height: 8),
                   TextField(
                     controller: weightController,
                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
                     decoration: InputDecoration(
                       hintText: 'np. 75.5',
                       suffixText: 'kg',
                       prefixIcon: const Icon(
                         Icons.monitor_weight,
                         color: Color(0xFFA69DF5),
                       ),
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: BorderSide(color: Colors.grey[300]!),
                       ),
                       enabledBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: BorderSide(color: Colors.grey[300]!),
                       ),
                       focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: const BorderSide(color: Color(0xFFA69DF5), width: 2),
                       ),
                       errorBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: const BorderSide(color: Colors.red, width: 2),
                       ),
                       focusedErrorBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: const BorderSide(color: Colors.red, width: 2),
                       ),
                       errorText: errorMessage,
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                     ),
                   ),
                 ],
               ),
             ),
             actions: [
               TextButton(
                 onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                 child: Text(
                   'Anuluj',
                   style: TextStyle(
                     color: Colors.grey[600],
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ),
               ElevatedButton(
                 onPressed: isLoading ? null : () async {
                   final weightText = weightController.text.trim();
                   if (weightText.isEmpty) {
                     setState(() {
                       errorMessage = 'Wprowadź wagę';
                     });
                     return;
                   }
                   
                   final weight = double.tryParse(weightText.replaceAll(',', '.'));
                   if (weight == null || weight <= 0 || weight > 500) {
                     setState(() {
                       errorMessage = 'Wprowadź prawidłową wagę (1-500 kg)';
                     });
                     return;
                   }
                   
                   setState(() {
                     isLoading = true;
                     errorMessage = null;
                   });
                   
                   try {
                     if (existingMeasurement != null) {
                       // Aktualizuje istniejący pomiar
                       final request = UpdateWeightMeasurementRequest(
                         measurementDate: selectedDate,
                         weightKg: weight,
                       );
                       
                       await weightService.updateWeightMeasurement(existingMeasurement.id, request);
                       
                       if (!context.mounted) return;
                       
                       Navigator.of(context).pop();
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(
                           content: Text('Pomiar został zaktualizowany'),
                           backgroundColor: Color(0xFFA69DF5),
                           behavior: SnackBarBehavior.floating,
                         ),
                       );
                     } else {
                       // Sprawdza czy na tę datę już istnieje pomiar
                       final existingOnDate = allMeasurements.where((m) => 
                         m.measurementDate.year == selectedDate.year &&
                         m.measurementDate.month == selectedDate.month &&
                         m.measurementDate.day == selectedDate.day
                       ).firstOrNull;
                       
                       if (existingOnDate != null) {
                         // Pomiar istnieje - aktualizuje
                         final request = UpdateWeightMeasurementRequest(
                           measurementDate: selectedDate,
                           weightKg: weight,
                         );
                         
                         await weightService.updateWeightMeasurement(existingOnDate.id, request);
                         
                         if (!context.mounted) return;
                         
                         Navigator.of(context).pop();
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(
                             content: Text('Pomiar został zaktualizowany'),
                             backgroundColor: Color(0xFFA69DF5),
                             behavior: SnackBarBehavior.floating,
                           ),
                         );
                         
                         onSuccess();
                         return;
                       } else {
                         // Dodaje nowy pomiar
                         final request = CreateWeightMeasurementRequest(
                           measurementDate: selectedDate,
                           weightKg: weight,
                         );
                         
                         await weightService.createWeightMeasurement(request);
                         
                         if (!context.mounted) return;
                         
                         Navigator.of(context).pop();
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(
                             content: Text('Pomiar został dodany'),
                             backgroundColor: Color(0xFFA69DF5),
                             behavior: SnackBarBehavior.floating,
                           ),
                         );
                       }
                     }
                     
                     // Odświeża dane
                     onSuccess();
                     
                   } catch (e) {
                     setState(() {
                       isLoading = false;
                       errorMessage = 'Błąd podczas zapisywania';
                     });
                   }
                 },
                 style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA69DF5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                 child: isLoading 
                     ? const SizedBox(
                         width: 20,
                         height: 20,
                         child: CircularProgressIndicator(
                           color: Colors.white,
                           strokeWidth: 2,
                         ),
                       )
                     : Text(
                         existingMeasurement != null ? 'Aktualizuj' : 'Dodaj',
                         style: const TextStyle(
                           fontWeight: FontWeight.w600,
                           fontSize: 16,
                         ),
                       ),
               ),
             ],
             actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
           );
         },
       );
     },
   );
 }
}