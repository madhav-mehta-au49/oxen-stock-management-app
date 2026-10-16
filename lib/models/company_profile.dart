/// Company profile stored at `meta/company` — drives the challan PDF.
class CompanyProfile {
  const CompanyProfile({
    required this.name,
    required this.tagline,
    required this.address,
    required this.phone,
    required this.gstin,
  });

  final String name;
  final String tagline;
  final String address;
  final String phone;
  final String gstin;

  static const CompanyProfile fallback = CompanyProfile(
    name: 'Oxen Energies',
    tagline: 'Solar Equipment & EPC Supplies',
    address: 'Hirji Mistry Road, Jamnagar',
    phone: '+91 88666 99444',
    gstin: '08AAFCO1234K1ZP',
  );

  Map<String, dynamic> toMap() => {
        'name': name,
        'tagline': tagline,
        'address': address,
        'phone': phone,
        'gstin': gstin,
      };

  factory CompanyProfile.fromMap(Map<String, dynamic> data) => CompanyProfile(
        name: data['name'] as String? ?? fallback.name,
        tagline: data['tagline'] as String? ?? fallback.tagline,
        address: data['address'] as String? ?? fallback.address,
        phone: data['phone'] as String? ?? fallback.phone,
        gstin: data['gstin'] as String? ?? fallback.gstin,
      );
}
