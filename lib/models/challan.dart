import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallanStatus {
  draft('Draft'),
  issued('Issued');

  const ChallanStatus(this.label);
  final String label;
}

/// Layout template used when the challan PDF is generated.
enum ChallanFormat {
  letterhead(
    'Letterhead',
    'Printed on the company letter pad.',
  ),
  plain(
    'Plain sheet',
    'Clean white sheet without the letterhead.',
  );

  const ChallanFormat(this.label, this.description);

  final String label;
  final String description;

  /// Short token appended to the generated file name.
  String get fileToken => name;
}

class ChallanLine {
  const ChallanLine({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.availableBefore,
  });

  final String itemId;
  final String itemName;
  final String sku;
  final String unit;
  final int quantity;
  final double rate;
  final int availableBefore;

  double get amount => quantity * rate;

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'itemName': itemName,
        'sku': sku,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'availableBefore': availableBefore,
      };

  factory ChallanLine.fromMap(Map<String, dynamic> data) => ChallanLine(
        itemId: data['itemId'] as String? ?? '',
        itemName: data['itemName'] as String? ?? '',
        sku: data['sku'] as String? ?? '',
        unit: data['unit'] as String? ?? 'Unit',
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        rate: (data['rate'] as num?)?.toDouble() ?? 0,
        availableBefore: (data['availableBefore'] as num?)?.toInt() ?? 0,
      );

  ChallanLine copyWith({int? quantity}) => ChallanLine(
        itemId: itemId,
        itemName: itemName,
        sku: sku,
        unit: unit,
        quantity: quantity ?? this.quantity,
        rate: rate,
        availableBefore: availableBefore,
      );
}

class Challan {
  const Challan({
    required this.id,
    required this.number,
    required this.customerName,
    required this.siteName,
    required this.address,
    required this.contact,
    required this.date,
    required this.lines,
    required this.status,
    this.vehicleNo = '',
    this.notes = '',
    this.preparedBy = 'Store Team',
    this.format = ChallanFormat.letterhead,
  });

  final String id;
  final String number;
  final String customerName;
  final String siteName;
  final String address;
  final String contact;
  final DateTime date;
  final List<ChallanLine> lines;
  final ChallanStatus status;
  final String vehicleNo;
  final String notes;
  final String preparedBy;
  final ChallanFormat format;

  int get totalUnits => lines.fold(0, (acc, l) => acc + l.quantity);

  double get totalValue => lines.fold(0, (acc, l) => acc + l.amount);

  Map<String, dynamic> toMap() => {
        'number': number,
        'customerName': customerName,
        'siteName': siteName,
        'address': address,
        'contact': contact,
        'date': Timestamp.fromDate(date),
        'lines': lines.map((l) => l.toMap()).toList(),
        'status': status.name,
        'vehicleNo': vehicleNo,
        'notes': notes,
        'preparedBy': preparedBy,
        'format': format.name,
        'totalUnits': totalUnits,
        'totalValue': totalValue,
      };

  factory Challan.fromMap(String id, Map<String, dynamic> data) => Challan(
        id: id,
        number: data['number'] as String? ?? '',
        customerName: data['customerName'] as String? ?? '',
        siteName: data['siteName'] as String? ?? '',
        address: data['address'] as String? ?? '',
        contact: data['contact'] as String? ?? '',
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        lines: ((data['lines'] as List?) ?? const [])
            .map((e) =>
                ChallanLine.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        status: ChallanStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => ChallanStatus.issued,
        ),
        vehicleNo: data['vehicleNo'] as String? ?? '',
        notes: data['notes'] as String? ?? '',
        preparedBy: data['preparedBy'] as String? ?? 'Store Team',
        format: ChallanFormat.values.firstWhere(
          (f) => f.name == data['format'],
          orElse: () => ChallanFormat.letterhead,
        ),
      );

  bool get isIssued => status != ChallanStatus.draft;

  Challan copyWith({
    ChallanStatus? status,
    List<ChallanLine>? lines,
    String? vehicleNo,
    String? notes,
    ChallanFormat? format,
  }) {
    return Challan(
      id: id,
      number: number,
      customerName: customerName,
      siteName: siteName,
      address: address,
      contact: contact,
      date: date,
      lines: lines ?? this.lines,
      status: status ?? this.status,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      notes: notes ?? this.notes,
      preparedBy: preparedBy,
      format: format ?? this.format,
    );
  }
}
