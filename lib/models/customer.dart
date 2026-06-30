class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final DateTime joinedDate;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.joinedDate,
  });

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    id: map['id'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String,
    address: map['address'] as String,
    joinedDate: DateTime.parse(map['joined_date'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'joined_date': joinedDate.toIso8601String(),
  };
}
