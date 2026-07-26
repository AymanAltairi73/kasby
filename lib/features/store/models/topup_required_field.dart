class TopupRequiredField {
  final String name;
  final String type;
  final List<String> options;

  TopupRequiredField({
    required this.name,
    required this.type,
    required this.options,
  });

  factory TopupRequiredField.fromJson(Map<String, dynamic> json) {
    return TopupRequiredField(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      options: (json['options'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'options': options,
    };
  }

  TopupRequiredField copyWith({
    String? name,
    String? type,
    List<String>? options,
  }) {
    return TopupRequiredField(
      name: name ?? this.name,
      type: type ?? this.type,
      options: options ?? this.options,
    );
  }
}
