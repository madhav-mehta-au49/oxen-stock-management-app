import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../data/repositories/item_image_repository.dart';
import '../../models/item_glyph.dart';
import '../../models/stock_item.dart';
import '../../providers/stock_providers.dart';
import '../../services/image_service.dart';

/// Add / edit an item. Submit only mutates local in-memory state.
class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.item});

  final StockItem? item;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _reorder;
  late final TextEditingController _purchase;
  late final TextEditingController _selling;
  late final TextEditingController _supplier;
  late final TextEditingController _unitNos;

  late ItemCategory _category;
  CompressedImage? _image;
  bool _removePhoto = false;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _qty = TextEditingController(text: item == null ? '' : '${item.quantity}');
    _reorder = TextEditingController(text: item == null ? '' : '${item.reorderLevel}');
    _purchase = TextEditingController(
      text: item == null ? '' : item.purchasePrice.toStringAsFixed(0),
    );
    _selling = TextEditingController(
      text: item == null ? '' : item.sellingPrice.toStringAsFixed(0),
    );
    _supplier = TextEditingController(text: item?.supplier ?? '');
    _unitNos = TextEditingController(text: item?.unitNos ?? '');
    _category = item?.category ?? ItemCategory.panels;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _qty,
      _reorder,
      _purchase,
      _selling,
      _supplier,
      _unitNos,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final picked = await AppSheet.show<ItemCategory>(
      context,
      title: 'Category',
      subtitle: 'Group items for filtering and reporting',
      builder: (context) => Column(
        children: [
          for (final c in ItemCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SheetOptionTile(
                title: c.label,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(c.icon, color: AppColors.primaryDeep, size: 20),
                ),
                selected: _category == c,
                onTap: () => Navigator.of(context).pop(c),
              ),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickPhoto() async {
    final source = await AppSheet.show<ImageSource>(
      context,
      title: 'Product photo',
      subtitle: 'Choose a source',
      builder: (context) => Column(
        children: [
          SheetOptionTile(
            title: 'Take a photo',
            subtitle: 'Use the camera',
            leading: const Icon(Icons.photo_camera_rounded),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: 8),
          SheetOptionTile(
            title: 'Choose from gallery',
            subtitle: 'Pick an existing image',
            leading: const Icon(Icons.photo_library_rounded),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 92,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final compressed = await ImageService.compress(bytes);
      if (!mounted) return;
      setState(() {
        _image = compressed;
        _removePhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Could not load that image');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final existing = widget.item;
    final thumb = _image != null
        ? base64Encode(_image!.thumb)
        : (_removePhoto ? '' : (existing?.imageThumb ?? ''));

    final item = StockItem(
      id: existing?.id ?? '',
      name: _name.text.trim(),
      category: _category,
      sku: existing?.sku ?? '',
      unit: 'Unit',
      quantity: int.tryParse(_qty.text.trim()) ?? 0,
      reorderLevel: int.tryParse(_reorder.text.trim()) ?? 0,
      purchasePrice: double.tryParse(_purchase.text.trim()) ?? 0,
      sellingPrice: double.tryParse(_selling.text.trim()) ?? 0,
      supplier: _supplier.text.trim(),
      glyphKey: _category.glyphKey,
      rack: existing?.rack ?? '',
      unitNos: _unitNos.text.trim(),
      imageThumb: thumb,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    final res = await ref.read(stockProvider.notifier).upsertItem(item);
    if (!mounted) return;

    if (!res.result.ok) {
      setState(() => _saving = false);
      AppToast.error(context, res.result.message);
      return;
    }

    // Full-size photo is stored separately (best-effort).
    try {
      if (_image != null) {
        await const ItemImageRepository().saveFull(res.id, _image!.full);
      } else if (_removePhoto) {
        await const ItemImageRepository().delete(res.id);
      }
    } catch (_) {
      // Thumbnail already saved; ignore full-image failure.
    }

    if (!mounted) return;
    setState(() => _saving = false);
    AppToast.success(context, res.result.message);
    Navigator.of(context).pop();
  }

  Widget _photoBox(ThemeData theme) {
    final existing = widget.item;
    Uint8List? bytes = _image?.thumb;
    if (bytes == null && !_removePhoto && existing != null &&
        existing.imageThumb.isNotEmpty) {
      try {
        bytes = base64Decode(existing.imageThumb);
      } catch (_) {
        bytes = null;
      }
    }
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      child: bytes == null
          ? Builder(builder: (_) {
              final glyph = ItemGlyph.byKey(_category.glyphKey);
              return Icon(glyph.icon, color: glyph.color, size: 36);
            })
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit item' : 'New item')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            AppCard(
              child: Row(
                children: [
                  _photoBox(theme),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Product photo',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 3),
                        Text(
                          'Optional — otherwise the category icon is shown.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.add_a_photo_rounded,
                                  size: 17),
                              label: Text(_image != null ||
                                      (_removePhoto == false &&
                                          (widget.item?.imageThumb.isNotEmpty ??
                                              false))
                                  ? 'Change'
                                  : 'Add photo'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryDeep,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                            if (_image != null ||
                                (!_removePhoto &&
                                    (widget.item?.imageThumb.isNotEmpty ??
                                        false)))
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _image = null;
                                  _removePhoto = true;
                                }),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 17),
                                label: const Text('Remove'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'Basics'),
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _name,
                    label: 'Item name',
                    hint: 'e.g. Monocrystalline Panel 330W',
                    prefixIcon: Icons.label_outline_rounded,
                    required: true,
                    validator: (v) => (v ?? '').trim().length < 3
                        ? 'Enter at least 3 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppPickerField(
                    label: 'Category',
                    value: _category.label,
                    prefixIcon: _category.icon,
                    required: true,
                    onTap: _pickCategory,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _unitNos,
                    label: 'Unit Nos',
                    hint: 'e.g. UN-001 – UN-025',
                    prefixIcon: Icons.confirmation_number_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'Stock'),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _qty,
                          label: _isEdit ? 'On hand quantity' : 'Opening stock',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          required: true,
                          prefixIcon: Icons.inventory_2_rounded,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n < 0) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _reorder,
                          label: 'Reorder level',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.notifications_active_rounded,
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _purchase,
                          label: 'Purchase price (₹)',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.shopping_bag_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _selling,
                          label: 'Selling price (₹)',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.sell_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'Sourcing'),
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _supplier,
                    label: 'Supplier',
                    hint: 'e.g. SunRay Energies',
                    prefixIcon: Icons.local_shipping_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: _isEdit ? 'Save changes' : 'Add to inventory',
              icon: _isEdit ? Icons.check_rounded : Icons.add_rounded,
              loading: _saving,
              onTap: _save,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
