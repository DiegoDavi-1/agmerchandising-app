// Exemplo de integração da API com a câmera
// 
// Para usar em camera_brain_two.dart, adicione o seguinte após tirar a foto:
// 
// ```dart
// import 'services/backend_api_service.dart';
// 
// // Após capturar a foto
// await _uploadPhotoToBackend(savedImagePath, locationText);
// 
// Future<void> _uploadPhotoToBackend(String photoPath, String location) async {
//   try {
//     // Ler a foto como base64 ou salvar URL
//     final file = File(photoPath);
//     final bytes = await file.readAsBytes();
//     final base64Photo = base64Encode(bytes);
//     
//     // Chamar API
//     final api = ApiService();
//     final response = await api.uploadPhoto(
//       category: 'relatorio', // ou 'abastecimento', 'precificacao', etc.
//       photoUrl: base64Photo,
//       brandName: 'Nome da Marca',
//       location: location,
//       latitude: position.latitude,
//       longitude: position.longitude,
//       accuracy: position.accuracy,
//     );
//     
//     if (response['success']) {
//       AppLogger.info('Foto salva na API: ${response['data']['_id']}');
//     } else {
//       AppLogger.error('Erro ao salvar foto: ${response['error']}');
//     }
//   } catch (e) {
//     AppLogger.error('Erro ao fazer upload da foto', e);
//   }
// }
// ```
// 
// Para entrada/saída (brand_page.dart):
// ```dart
// final api = ApiService();
// await api.clockInOut(
//   type: 'entrada',
//   latitude: position.latitude,
//   longitude: position.longitude,
//   location: locationAddress,
//   accuracy: position.accuracy,
// );
// ```
// 
// Para salvar relatório (pdf_generator.dart):
// ```dart
// final api = ApiService();
// await api.saveReport(
//   brandName: brandData.brandName,
//   abastecimento: brandData.abastecimento,
//   precificacao: brandData.precificacao,
//   relatorio: brandData.relatorio,
//   pendenciaDescricao: brandData.pendenciaDescricao,
//   location: brandData.localizacao,
// );
// ```

// Este arquivo é apenas para documentação
// Copie os exemplos acima para integrar com seus widgets
// ignore_for_file: file_names

// Exemplo de integração da API com a câmera
// 
// Para usar em camera_brain_two.dart, adicione o seguinte após tirar a foto:
// 
// ```dart
// import 'services/backend_api_service.dart';
// 
// // Após capturar a foto
// await _uploadPhotoToBackend(savedImagePath, locationText);
// 
// Future<void> _uploadPhotoToBackend(String photoPath, String location) async {
//   try {
//     // Ler a foto como base64 ou salvar URL
//     final file = File(photoPath);
//     final bytes = await file.readAsBytes();
//     final base64Photo = base64Encode(bytes);
//     
//     // Chamar API
//     final api = ApiService();
//     final response = await api.uploadPhoto(
//       category: 'relatorio', // ou 'abastecimento', 'precificacao', etc.
//       photoUrl: base64Photo,
//       brandName: 'Nome da Marca',
//       location: location,
//       latitude: position.latitude,
//       longitude: position.longitude,
//       accuracy: position.accuracy,
//     );
//     
//     if (response['success']) {
//       AppLogger.info('Foto salva na API: ${response['data']['_id']}');
//     } else {
//       AppLogger.error('Erro ao salvar foto: ${response['error']}');
//     }
//   } catch (e) {
//     AppLogger.error('Erro ao fazer upload da foto', e);
//   }
// }
// ```
// 
// Para entrada/saída (brand_page.dart):
// ```dart
// final api = ApiService();
// await api.clockInOut(
//   type: 'entrada',
//   latitude: position.latitude,
//   longitude: position.longitude,
//   location: locationAddress,
//   accuracy: position.accuracy,
// );
// ```
// 
// Para salvar relatório (pdf_generator.dart):
// ```dart
// final api = ApiService();
// await api.saveReport(
//   brandName: brandData.brandName,
//   abastecimento: brandData.abastecimento,
//   precificacao: brandData.precificacao,
//   relatorio: brandData.relatorio,
//   pendenciaDescricao: brandData.pendenciaDescricao,
//   location: brandData.localizacao,
// );
// ```

// Este arquivo é apenas para documentação
// Copie os exemplos acima para integrar com seus widgets
