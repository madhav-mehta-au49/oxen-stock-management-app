import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallanStatus {
  draft('Draft'),
  issued('Issued'),
  cancelled('Cancelled');

  const ChallanStatus(this.label);
  final String label;
}

/// Layout template used when the challan PDF is generated.
enum ChallanFormat {
  letterhead('Letterhead', 'Printed on the company letter pad.'),
  plain('Plain sheet', 'Clean white sheet without the letterhead.');

  const ChallanFormat(this.label, this.description);

  final String label;
  final String description;

  /// Short token appended to the generated file name.
  String get fileToken => name;
}

/// A Bill-To or Ship-To block. Bill-To is snapshotted from the customer;
/// Ship-To is entered manually on each challan.
class ChallanParty {
  const ChallanParty({
    required this.name,
    this.siteProject = '',
    required this.address,
    required this.phone,
    required this.gstin,
    required this.contactPerson,
  });

  final String name;
  final String siteProject;
  final String address;
  final String phone;
  final String gstin;
  final String contactPerson;

  static const ChallanParty empty = ChallanParty(
    name: '',
    siteProject: '',
    address: '',
    phone: '',
    gstin: '',
    contactPerson: '',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'siteProject': siteProject,
    'address': address,
    'phone': phone,
    'gstin': gstin,
    'contactPerson': contactPerson,
  };

  factory ChallanParty.fromMap(Map<String, dynamic>? data) => ChallanParty(
    name: data?['name'] as String? ?? '',
    siteProject: data?['siteProject'] as String? ?? '',
    address: data?['address'] as String? ?? '',
    phone: data?['phone'] as String? ?? '',
    gstin: data?['gstin'] as String? ?? '',
    contactPerson: data?['contactPerson'] as String? ?? '',
  );

  ChallanParty copyWith({
    String? name,
    String? siteProject,
    String? address,
    String? phone,
    String? gstin,
    String? contactPerson,
  }) => ChallanParty(
    name: name ?? this.name,
    siteProject: siteProject ?? this.siteProject,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    gstin: gstin ?? this.gstin,
    contactPerson: contactPerson ?? this.contactPerson,
  );
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
    this.gstRate = 0,
    this.gstAmount = 0,
  });

  final String itemId;
  final String itemName;
  final String sku;
  final String unit;
  final int quantity;

  /// Unit price (excl. GST) per piece. For solar modules this is Wp × ₹/Wp.
  final double rate;
  final int availableBefore;

  /// Single GST % applied to this line (snapshot at issue time).
  final double gstRate;

  /// GST amount for the line (excl. GST value × gstRate).
  final double gstAmount;

  /// Taxable value (qty × rate, excl. GST).
  double get amount => quantity * rate;

  /// Line total including GST.
  double get totalAmount => amount + gstAmount;

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'sku': sku,
    'unit': unit,
    'quantity': quantity,
    'rate': rate,
    'availableBefore': availableBefore,
    'gstRate': gstRate,
    'gstAmount': gstAmount,
  };

  factory ChallanLine.fromMap(Map<String, dynamic> data) => ChallanLine(
    itemId: data['itemId'] as String? ?? '',
    itemName: data['itemName'] as String? ?? '',
    sku: data['sku'] as String? ?? '',
    unit: data['unit'] as String? ?? 'Unit',
    quantity: (data['quantity'] as num?)?.toInt() ?? 0,
    rate: (data['rate'] as num?)?.toDouble() ?? 0,
    availableBefore: (data['availableBefore'] as num?)?.toInt() ?? 0,
    gstRate: (data['gstRate'] as num?)?.toDouble() ?? 0,
    gstAmount: (data['gstAmount'] as num?)?.toDouble() ?? 0,
  );

  ChallanLine copyWith({
    int? quantity,
    double? rate,
    double? gstRate,
    double? gstAmount,
  }) => ChallanLine(
    itemId: itemId,
    itemName: itemName,
    sku: sku,
    unit: unit,
    quantity: quantity ?? this.quantity,
    rate: rate ?? this.rate,
    availableBefore: availableBefore,
    gstRate: gstRate ?? this.gstRate,
    gstAmount: gstAmount ?? this.gstAmount,
  );
}

class Challan {
  const Challan({
    required this.id,
    required this.number,
    required this.customerId,
    required this.billTo,
    required this.shipTo,
    this.sameAsBillTo = false,
    required this.date,
    required this.lines,
    required this.status,
    this.vehicleNo = '',
    this.notes = '',
    this.preparedBy = 'Store Team',
    this.format = ChallanFormat.letterhead,
    this.createdBy = '',
    this.createdByName = '',
    this.updatedBy = '',
    this.updatedByName = '',
    this.cancelledBy = '',
    this.cancelledByName = '',
    this.cancelledAt,
    this.cancelRemarks = '',
  });

  final String id;
  final String number;
  final String customerId;
  final ChallanParty billTo;
  final ChallanParty shipTo;
  final bool sameAsBillTo;
  final DateTime date;
  final List<ChallanLine> lines;
  final ChallanStatus status;
  final String vehicleNo;
  final String notes;
  final String preparedBy;
  final ChallanFormat format;

  /// Audit trail (who created / last edited / cancelled the challan).
  final String createdBy;
  final String createdByName;
  final String updatedBy;
  final String updatedByName;
  final String cancelledBy;
  final String cancelledByName;
  final DateTime? cancelledAt;
  final String cancelRemarks;

  int get totalUnits => lines.fold(0, (acc, l) => acc + l.quantity);

  /// Taxable value (excl. GST).
  double get totalValue => lines.fold(0, (acc, l) => acc + l.amount);

  /// Alias for clarity on the delivery note.
  double get taxableValue => totalValue;

  /// Total GST across all lines.
  double get gstValue => lines.fold(0, (acc, l) => acc + l.gstAmount);

  /// Taxable + GST before rounding.
  double get grossTotal => taxableValue + gstValue;

  /// Grand total rounded to the nearest rupee (half-up for positive amounts).
  double get grandTotal => grossTotal.roundToDouble();

  /// Difference introduced by rounding (e.g. +0.45 / -0.20).
  double get roundOff => grandTotal - grossTotal;

  /// GST amount grouped by rate, for the delivery-note summary.
  Map<double, double> get gstBreakdown {
    final map = <double, double>{};
    for (final l in lines) {
      if (l.gstRate <= 0 || l.gstAmount <= 0) continue;
      map.update(
        l.gstRate,
        (v) => v + l.gstAmount,
        ifAbsent: () => l.gstAmount,
      );
    }
    return map;
  }

  bool get isIssued => status == ChallanStatus.issued;
  bool get isCancelled => status == ChallanStatus.cancelled;

  Map<String, dynamic> toMap() => {
    'number': number,
    'customerId': customerId,
    'billTo': billTo.toMap(),
    'shipTo': shipTo.toMap(),
    'sameAsBillTo': sameAsBillTo,
    'date': Timestamp.fromDate(date),
    'lines': lines.map((l) => l.toMap()).toList(),
    'status': status.name,
    'vehicleNo': vehicleNo,
    'notes': notes,
    'preparedBy': preparedBy,
    'format': format.name,
    'totalUnits': totalUnits,
    'taxableValue': taxableValue,
    'gstValue': gstValue,
    'roundOff': roundOff,
    'grandTotal': grandTotal,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'updatedBy': updatedBy,
    'updatedByName': updatedByName,
    'cancelledBy': cancelledBy,
    'cancelledByName': cancelledByName,
    'cancelledAt': cancelledAt == null
        ? null
        : Timestamp.fromDate(cancelledAt!),
    'cancelRemarks': cancelRemarks,
  };

  factory Challan.fromMap(String id, Map<String, dynamic> data) {
    // Backward compatibility: challans saved before Bill/Ship had
    // customerName/siteName/address/contact.
    final legacyName = data['customerName'] as String? ?? '';
    final legacySite = data['siteName'] as String? ?? '';
    final legacyAddress = data['address'] as String? ?? '';
    final legacyContact = data['contact'] as String? ?? '';
    final billMap = (data['billTo'] as Map?)?.cast<String, dynamic>();
    final shipMap = (data['shipTo'] as Map?)?.cast<String, dynamic>();

    final billTo = billMap != null
        ? ChallanParty.fromMap(billMap)
        : ChallanParty(
            name: legacyName,
            address: legacyAddress,
            phone: legacyContact,
            gstin: '',
            contactPerson: '',
          );
    final shipTo = shipMap != null
        ? ChallanParty.fromMap(shipMap)
        : ChallanParty(
            name: legacyName,
            siteProject: legacySite,
            address: legacyAddress,
            phone: legacyContact,
            gstin: '',
            contactPerson: '',
          );

    return Challan(
      id: id,
      number: data['number'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      billTo: billTo,
      shipTo: shipTo,
      sameAsBillTo: data['sameAsBillTo'] as bool? ?? false,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lines: ((data['lines'] as List?) ?? const [])
          .map((e) => ChallanLine.fromMap(Map<String, dynamic>.from(e as Map)))
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
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      updatedBy: data['updatedBy'] as String? ?? '',
      updatedByName: data['updatedByName'] as String? ?? '',
      cancelledBy: data['cancelledBy'] as String? ?? '',
      cancelledByName: data['cancelledByName'] as String? ?? '',
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      cancelRemarks: data['cancelRemarks'] as String? ?? '',
    );
  }

  Challan copyWith({
    String? id,
    String? number,
    ChallanStatus? status,
    List<ChallanLine>? lines,
    ChallanParty? billTo,
    ChallanParty? shipTo,
    bool? sameAsBillTo,
    String? customerId,
    String? vehicleNo,
    String? notes,
    ChallanFormat? format,
    DateTime? date,
    String? createdBy,
    String? createdByName,
    String? updatedBy,
    String? updatedByName,
    String? cancelledBy,
    String? cancelledByName,
    DateTime? cancelledAt,
    String? cancelRemarks,
  }) => Challan(
    id: id ?? this.id,
    number: number ?? this.number,
    customerId: customerId ?? this.customerId,
    billTo: billTo ?? this.billTo,
    shipTo: shipTo ?? this.shipTo,
    sameAsBillTo: sameAsBillTo ?? this.sameAsBillTo,
    date: date ?? this.date,
    lines: lines ?? this.lines,
    status: status ?? this.status,
    vehicleNo: vehicleNo ?? this.vehicleNo,
    notes: notes ?? this.notes,
    preparedBy: preparedBy,
    format: format ?? this.format,
    createdBy: createdBy ?? this.createdBy,
    createdByName: createdByName ?? this.createdByName,
    updatedBy: updatedBy ?? this.updatedBy,
    updatedByName: updatedByName ?? this.updatedByName,
    cancelledBy: cancelledBy ?? this.cancelledBy,
    cancelledByName: cancelledByName ?? this.cancelledByName,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancelRemarks: cancelRemarks ?? this.cancelRemarks,
  );
}
