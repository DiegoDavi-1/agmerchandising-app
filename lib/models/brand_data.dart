class PhotoData {
  final String path;
  final String? location;
  final DateTime timestamp;
  
  PhotoData({
    required this.path,
    this.location,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory PhotoData.fromJson(Map<String, dynamic> json) {
    return PhotoData(
      path: json['path'],
      location: json['location'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class TimeClockEntry {
  final DateTime dateTime;
  final String type; // 'Entrada' ou 'Saída'
  final String? location;
  final String? photoPath; // Selfie de verificação
  final double? latitude;
  final double? longitude;
  final double? accuracy; // Precisão em metros
  final bool? isMockLocation; // Detecta localização falsa
  final double? altitude;
  final double? speed;
  
  TimeClockEntry({
    required this.dateTime,
    required this.type,
    this.location,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.isMockLocation,
    this.altitude,
    this.speed,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'dateTime': dateTime.toIso8601String(),
      'type': type,
      'location': location,
      'photoPath': photoPath,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'isMockLocation': isMockLocation,
      'altitude': altitude,
      'speed': speed,
    };
  }
  
  factory TimeClockEntry.fromJson(Map<String, dynamic> json) {
    return TimeClockEntry(
      dateTime: DateTime.parse(json['dateTime']),
      type: json['type'],
      location: json['location'],
      photoPath: json['photoPath'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      accuracy: json['accuracy'],
      isMockLocation: json['isMockLocation'],
      altitude: json['altitude'],
      speed: json['speed'],
    );
  }
  
  // Verifica se a localização é confiável
  bool get isLocationReliable {
    if (isMockLocation == true) return false;
    if (accuracy == null || accuracy! > 50) return false; // > 50m não é confiável
    return true;
  }
  
  // Texto de status de segurança
  String get securityStatus {
    if (isMockLocation == true) return '⚠️ Localização Falsa Detectada';
    if (accuracy == null) return '❓ Sem dados de GPS';
    if (accuracy! > 50) return '⚠️ Precisão baixa (${accuracy!.toStringAsFixed(0)}m)';
    if (accuracy! > 20) return '✓ Precisão moderada (${accuracy!.toStringAsFixed(0)}m)';
    return '✓ Alta precisão (${accuracy!.toStringAsFixed(0)}m)';
  }
}

// Classe para foto com descrição por categoria
class CategoryPhoto {
  String? photoPath;
  String description;
  String? location;
  DateTime? timestamp;
  
  CategoryPhoto({
    this.photoPath,
    this.description = '',
    this.location,
    this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'photoPath': photoPath,
      'description': description,
      'location': location,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
  
  factory CategoryPhoto.fromJson(Map<String, dynamic> json) {
    return CategoryPhoto(
      photoPath: json['photoPath'],
      description: json['description'] ?? '',
      location: json['location'],
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }
  
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
}

class BrandData {
  final String brandName;
  bool abastecimento = false;
  bool precificacao = false;
  bool relatorio = false;
  bool pendencia = false;
  String pendenciaDescricao = '';
  List<String> fotos = [];
  List<PhotoData> fotosComLocalizacao = [];
  List<TimeClockEntry> pontoEntradas = [];
  DateTime? dataRegistro;
  String? localizacao;
  String observacoes = '';
  
  // Fotos por categoria
  CategoryPhoto fotoAbastecimento = CategoryPhoto();
  CategoryPhoto fotoPrecificacao = CategoryPhoto();
  CategoryPhoto fotoRelatorio = CategoryPhoto();
  CategoryPhoto fotoPendencia = CategoryPhoto();
  
  BrandData({required this.brandName});
  
  Map<String, dynamic> toJson() {
    return {
      'brandName': brandName,
      'abastecimento': abastecimento,
      'precificacao': precificacao,
      'relatorio': relatorio,
      'pendencia': pendencia,
      'pendenciaDescricao': pendenciaDescricao,
      'fotos': fotos,
      'fotosComLocalizacao': fotosComLocalizacao.map((f) => f.toJson()).toList(),
      'pontoEntradas': pontoEntradas.map((e) => e.toJson()).toList(),
      'dataRegistro': dataRegistro?.toIso8601String(),
      'localizacao': localizacao,
      'observacoes': observacoes,
      'fotoAbastecimento': fotoAbastecimento.toJson(),
      'fotoPrecificacao': fotoPrecificacao.toJson(),
      'fotoRelatorio': fotoRelatorio.toJson(),
      'fotoPendencia': fotoPendencia.toJson(),
    };
  }
  
  factory BrandData.fromJson(Map<String, dynamic> json) {
    final brand = BrandData(brandName: json['brandName']);
    brand.abastecimento = json['abastecimento'] ?? false;
    brand.precificacao = json['precificacao'] ?? false;
    brand.relatorio = json['relatorio'] ?? false;
    brand.pendencia = json['pendencia'] ?? false;
    brand.pendenciaDescricao = json['pendenciaDescricao'] ?? '';
    brand.fotos = (json['fotos'] as List?)?.cast<String>() ?? [];
    brand.fotosComLocalizacao = (json['fotosComLocalizacao'] as List?)
        ?.map((f) => PhotoData.fromJson(f))
        .toList() ?? [];
    brand.pontoEntradas = (json['pontoEntradas'] as List?)
        ?.map((e) => TimeClockEntry.fromJson(e))
        .toList() ?? [];
    brand.dataRegistro = json['dataRegistro'] != null 
        ? DateTime.parse(json['dataRegistro']) 
        : null;
    brand.localizacao = json['localizacao'];
    brand.observacoes = json['observacoes'] ?? '';
    
    // Carregar fotos por categoria
    if (json['fotoAbastecimento'] != null) {
      brand.fotoAbastecimento = CategoryPhoto.fromJson(json['fotoAbastecimento']);
    }
    if (json['fotoPrecificacao'] != null) {
      brand.fotoPrecificacao = CategoryPhoto.fromJson(json['fotoPrecificacao']);
    }
    if (json['fotoRelatorio'] != null) {
      brand.fotoRelatorio = CategoryPhoto.fromJson(json['fotoRelatorio']);
    }
    if (json['fotoPendencia'] != null) {
      brand.fotoPendencia = CategoryPhoto.fromJson(json['fotoPendencia']);
    }
    
    return brand;
  }
}
