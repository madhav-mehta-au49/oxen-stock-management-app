import 'package:cloud_firestore/cloud_firestore.dart';

import 'challan.dart';

/// Lifecycle of a Proforma Invoice.
enum ProformaStatus {
  issued('Issued'),
  converted('Converted'),
  cancelled('Cancelled');

  const ProformaStatus(this.label);
  final String label;
}

/// A Proforma Invoice (PI): a quotation built from current stock. It does **not**
/// affect stock. It reuses the challan's parties, lines and format so it can be
/// converted 1:1 into a delivery challan.
class Proforma {
  const Proforma({
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
    this.validityDays = 7,
    this.createdBy = '',
    this.createdByName = '',
    this.updatedBy = '',
    this.updatedByName = '',
    this.cancelledBy = '',
    this.cancelledByName = '',
    this.cancelledAt,
    this.cancelRemarks = '',
    this.convertedAt,
    this.challanNumber = '',
  });

  final String id;
  final String number;
  final String customerId;
  final ChallanParty billTo;
  final ChallanParty shipTo;
  final bool sameAsBillTo;
  final DateTime date;
  final List<ChallanLine> lines;
  final ProformaStatus status;
  final String vehicleNo;
  final String notes;
  final String preparedBy;
  final ChallanFormat format;

  /// How many days this quotation is valid (editable per PI; shown on the PDF).
  final int validityDays;

  final String createdBy;
  final String createdByName;
  final String updatedBy;
  final String updatedByName;
  final String cancelledBy;
  final String cancelledByName;
  final DateTime? cancelledAt;
  final String cancelRemarks;
  final DateTime? convertedAt;
  final String challanNumber;

  int get totalUnits => lines.fold(0, (acc, l) => acc + l.quantity);
  double get totalValue => lines.fold(0, (acc, l) => acc + l.amount);
  double get taxableValue => totalValue;
  double get gstValue => lines.fold(0, (acc, l) => acc + l.gstAmount);
  double get grossTotal => taxableValue + gstValue;
  double get grandTotal => grossTotal.roundToDouble();
  double get roundOff => grandTotal - grossTotal;

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

  bool get isConverted => status == ProformaStatus.converted;
  bool get isCancelled => status == ProformaStatus.cancelled;

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
    'validityDays': validityDays,
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
    'convertedAt': convertedAt == null
        ? null
        : Timestamp.fromDate(convertedAt!),
    'challanNumber': challanNumber,
  };

  factory Proforma.fromMap(String id, Map<String, dynamic> data) => Proforma(
    id: id,
    number: data['number'] as String? ?? '',
    customerId: data['customerId'] as String? ?? '',
    billTo: ChallanParty.fromMap(
      (data['billTo'] as Map?)?.cast<String, dynamic>(),
    ),
    shipTo: ChallanParty.fromMap(
      (data['shipTo'] as Map?)?.cast<String, dynamic>(),
    ),
    sameAsBillTo: data['sameAsBillTo'] as bool? ?? false,
    date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    lines: ((data['lines'] as List?) ?? const [])
        .map((e) => ChallanLine.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
    status: ProformaStatus.values.firstWhere(
      (s) => s.name == data['status'],
      orElse: () => ProformaStatus.issued,
    ),
    vehicleNo: data['vehicleNo'] as String? ?? '',
    notes: data['notes'] as String? ?? '',
    preparedBy: data['preparedBy'] as String? ?? 'Store Team',
    format: ChallanFormat.values.firstWhere(
      (f) => f.name == data['format'],
      orElse: () => ChallanFormat.letterhead,
    ),
    validityDays: (data['validityDays'] as num?)?.toInt() ?? 7,
    createdBy: data['createdBy'] as String? ?? '',
    createdByName: data['createdByName'] as String? ?? '',
    updatedBy: data['updatedBy'] as String? ?? '',
    updatedByName: data['updatedByName'] as String? ?? '',
    cancelledBy: data['cancelledBy'] as String? ?? '',
    cancelledByName: data['cancelledByName'] as String? ?? '',
    cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    cancelRemarks: data['cancelRemarks'] as String? ?? '',
    convertedAt: (data['convertedAt'] as Timestamp?)?.toDate(),
    challanNumber: data['challanNumber'] as String? ?? '',
  );

  /// Builds a challan to issue for this PI (same customer, lines and format).
  Challan toChallan() => Challan(
    id: '',
    number: '',
    customerId: customerId,
    billTo: billTo,
    shipTo: shipTo,
    sameAsBillTo: sameAsBillTo,
    date: date,
    lines: lines,
    status: ChallanStatus.issued,
    vehicleNo: vehicleNo,
    notes: notes,
    format: format,
  );

  Proforma copyWith({
    String? id,
    String? number,
    ProformaStatus? status,
    List<ChallanLine>? lines,
    ChallanParty? billTo,
    ChallanParty? shipTo,
    bool? sameAsBillTo,
    String? customerId,
    String? vehicleNo,
    String? notes,
    ChallanFormat? format,
    int? validityDays,
    DateTime? date,
    String? updatedBy,
    String? updatedByName,
    String? cancelledBy,
    String? cancelledByName,
    DateTime? cancelledAt,
    String? cancelRemarks,
    DateTime? convertedAt,
    String? challanNumber,
  }) => Proforma(
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
    validityDays: validityDays ?? this.validityDays,
    createdBy: createdBy,
    createdByName: createdByName,
    updatedBy: updatedBy ?? this.updatedBy,
    updatedByName: updatedByName ?? this.updatedByName,
    cancelledBy: cancelledBy ?? this.cancelledBy,
    cancelledByName: cancelledByName ?? this.cancelledByName,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancelRemarks: cancelRemarks ?? this.cancelRemarks,
    convertedAt: convertedAt ?? this.convertedAt,
    challanNumber: challanNumber ?? this.challanNumber,
  );
}
