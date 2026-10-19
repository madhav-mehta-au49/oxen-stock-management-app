import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved customer. Bill-To address is stored here and reused on challans;
/// Ship-To is always entered on the challan itself.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.gstin,
    required this.billToAddress,
    required this.contactPerson,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String gstin;
  final String billToAddress;
  final String contactPerson;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'gstin': gstin,
        'billToAddress': billToAddress,
        'contactPerson': contactPerson,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Customer.fromMap(String id, Map<String, dynamic> data) => Customer(
        id: id,
        name: data['name'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
        gstin: data['gstin'] as String? ?? '',
        billToAddress: data['billToAddress'] as String? ?? '',
        contactPerson: data['contactPerson'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Customer copyWith({
    String? name,
    String? phone,
    String? gstin,
    String? billToAddress,
    String? contactPerson,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        gstin: gstin ?? this.gstin,
        billToAddress: billToAddress ?? this.billToAddress,
        contactPerson: contactPerson ?? this.contactPerson,
        createdAt: createdAt,
      );
}
