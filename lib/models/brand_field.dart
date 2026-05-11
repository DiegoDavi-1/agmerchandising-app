// Modelo para representar um campo customizável de uma marca
class BrandField {
  final int id;
  final int brandId;
  final String fieldType; // checkbox, photo, text, number, date, textarea
  final String fieldLabel;
  final String fieldName;
  final BrandFieldConfig? fieldConfig;
  final int displayOrder;

  BrandField({
    required this.id,
    required this.brandId,
    required this.fieldType,
    required this.fieldLabel,
    required this.fieldName,
    this.fieldConfig,
    required this.displayOrder,
  });

  factory BrandField.fromJson(Map<String, dynamic> json) {
    return BrandField(
      id: json['id'] as int,
      brandId: json['brand_id'] as int? ?? 0,
      fieldType: json['field_type'] as String,
      fieldLabel: json['field_label'] as String,
      fieldName: json['field_name'] as String,
      fieldConfig: json['field_config'] != null
          ? BrandFieldConfig.fromJson(json['field_config'] as Map<String, dynamic>)
          : null,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_id': brandId,
      'field_type': fieldType,
      'field_label': fieldLabel,
      'field_name': fieldName,
      'field_config': fieldConfig?.toJson(),
      'display_order': displayOrder,
    };
  }
}

// Configurações específicas de cada campo
class BrandFieldConfig {
  final bool? required;
  final bool? allowMultiple;
  final int? maxPhotos;
  final int? min;
  final int? max;

  BrandFieldConfig({
    this.required,
    this.allowMultiple,
    this.maxPhotos,
    this.min,
    this.max,
  });

  factory BrandFieldConfig.fromJson(Map<String, dynamic> json) {
    return BrandFieldConfig(
      required: json['required'] as bool?,
      allowMultiple: json['allow_multiple'] as bool?,
      maxPhotos: json['max_photos'] as int?,
      min: json['min'] as int?,
      max: json['max'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'required': required,
      'allow_multiple': allowMultiple,
      'max_photos': maxPhotos,
      'min': min,
      'max': max,
    };
  }
}

// Dados coletados de um campo
class BrandFieldData {
  final String fieldName;
  final dynamic value; // String, bool, int, List<String>, etc
  final String fieldType;

  BrandFieldData({
    required this.fieldName,
    required this.value,
    required this.fieldType,
  });

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'value': value,
      'field_type': fieldType,
    };
  }

  factory BrandFieldData.fromJson(Map<String, dynamic> json) {
    return BrandFieldData(
      fieldName: json['field_name'] as String,
      value: json['value'],
      fieldType: json['field_type'] as String,
    );
  }
}
