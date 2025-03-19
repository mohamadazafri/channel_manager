class Room {
  final String id;
  final String name;
  final String type;
  final int capacity;
  final double price;
  final bool isAvailable;
  final String? description;
  final String? imageUrl;

  Room({
    required this.id,
    required this.name,
    required this.type,
    required this.capacity,
    required this.price,
    this.isAvailable = true,
    this.description,
    this.imageUrl,
  });

  // Factory constructor to create a Room from JSON
  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      capacity: json['capacity'],
      price: json['price'].toDouble(),
      isAvailable: json['is_available'] ?? true,
      description: json['description'],
      imageUrl: json['image_url'],
    );
  }

  // Convert Room to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'capacity': capacity,
      'price': price,
      'is_available': isAvailable,
      'description': description,
      'image_url': imageUrl,
    };
  }

  // Create a copy of this room with optional new parameters
  Room copyWith({String? id, String? name, String? type, int? capacity, double? price, bool? isAvailable, String? description, String? imageUrl}) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Room &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.capacity == capacity &&
        other.price == price &&
        other.isAvailable == isAvailable &&
        other.description == description &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        type.hashCode ^
        capacity.hashCode ^
        price.hashCode ^
        isAvailable.hashCode ^
        description.hashCode ^
        imageUrl.hashCode;
  }

  @override
  String toString() {
    return 'Room(id: $id, name: $name, type: $type, capacity: $capacity, price: \$$price)';
  }
}
