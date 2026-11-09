/// Padrão de fotos do Merch Hub (o mesmo usado pelo PWA e pelo servidor).
/// Os limites valem para o lado maior da foto; fotos menores não são ampliadas.
class PhotoStandard {
  PhotoStandard._();

  // 2560 px / 88: etiquetas de preço e embalagens pequenas continuam legíveis para a IA.
  static const double fieldMaxSide = 2560;
  static const int fieldQuality = 88;

  static const double clockMaxSide = 1024;
  static const int clockQuality = 80;
}
