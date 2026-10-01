import 'package:flutter/material.dart';
import '../../services/batch_service.dart';
import '../../services/egg_service.dart';
import '../../widgets/app_card.dart';
import '../../core/app_theme.dart';

class EggStockScreen extends StatefulWidget {
  final int farmId;

  const EggStockScreen({super.key, required this.farmId});

  @override
  State<EggStockScreen> createState() => _EggStockScreenState();
}

class _EggStockScreenState extends State<EggStockScreen>
    with SingleTickerProviderStateMixin {
  final BatchService _batchService = BatchService();
  final EggService _eggService = EggService();

  // ── Data ────────────────────────────────────────────────────────────────
  List<dynamic> _batches = [];
  int? _selectedBatchId;
  List<dynamic> _yields = [];
  List<dynamic> _sales = [];
  Map<String, dynamic>? _crateSummary;

  bool _loadingBatches = true;
  bool _loadingData = false;
  bool _submitting = false;
  String? _error;

  // ── Sale Form ────────────────────────────────────────────────────────────
  String _selectedGrade = 'A';
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime? _selectedDate;

  // ── Animation ────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;

  // ── Grade meta ───────────────────────────────────────────────────────────
  static const _grades = ['A', 'B', 'C' /*, 'Broken' */];
  static const _gradeColors = {
    'A': Color(0xFF22C55E),
    'B': Color(0xFFF59E0B),
    'C': Color(0xFFEF4444),
    // 'Broken': Color(0xFF92400E),
  };
  static const _gradeIcons = {
    'A': Icons.workspace_premium,
    'B': Icons.star_half,
    'C': Icons.star_border,
    // 'Broken': Icons.broken_image_outlined,
  };

  // ── Computed helpers ─────────────────────────────────────────────────────
  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;
  double get _price => double.tryParse(_priceController.text.trim()) ?? 0.0;
  double get _totalAmount => _quantity * _price;

  /// produced - sold for each grade
  Map<String, int> get _available {
    final map = <String, int>{};
    for (final grade in _grades) {
      final y =
          _yields.firstWhere((e) => e['grade'] == grade, orElse: () => null);
      final produced = (y?['produced'] as num?)?.toInt() ?? 0;
      final sold = (y?['sold'] as num?)?.toInt() ?? 0;
      map[grade] = produced - sold;
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _loadBatches();
    _quantityController.addListener(() => setState(() {}));
    _priceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ── Loaders ──────────────────────────────────────────────────────────────
  Future<void> _loadBatches() async {
    setState(() {
      _loadingBatches = true;
      _error = null;
    });
    try {
      final batches = await _batchService.getBatchesByFarm(widget.farmId);
      setState(() {
        _batches = batches;
        _loadingBatches = false;
        if (_batches.isNotEmpty) {
          _selectedBatchId = _batches.first['batch_id'];
          _loadData();
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBatches = false;
      });
    }
  }

  Future<void> _loadData() async {
    if (_selectedBatchId == null) return;
    setState(() {
      _loadingData = true;
      _error = null;
    });
    try {
      final yields = await _eggService.getEggYields(_selectedBatchId!);
      final salesList = await _eggService.getEggSales(_selectedBatchId!);
      final crateSum = await _eggService.getCrateSummary(_selectedBatchId!);
      setState(() {
        _yields = yields;
        _sales = salesList;
        _crateSummary = crateSum;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingData = false);
    }
  }

  Widget _buildCrateSummaryCard() {
    if (_crateSummary == null) return const SizedBox.shrink();

    final total = _crateSummary!['total_crates'] as int? ?? 0;
    final excellent = _crateSummary!['excellent_crates'] as int? ?? 0;
    final good = _crateSummary!['good_crates'] as int? ?? 0;
    final average = _crateSummary!['average_crates'] as int? ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_rounded, color: Color(0xFF0D9488), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Crate Quality Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total Crates',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D9488)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCrateStatTile(
                  label: 'Excellent',
                  count: excellent,
                  color: const Color(0xFF2E7D32),
                  icon: Icons.verified_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCrateStatTile(
                  label: 'Good',
                  count: good,
                  color: const Color(0xFFF57F17),
                  icon: Icons.thumb_up_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCrateStatTile(
                  label: 'Average',
                  count: average,
                  color: const Color(0xFFD32F2F),
                  icon: Icons.info_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCrateStatTile({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  // ── Date picker ──────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.grey.shade800,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Submit sale ──────────────────────────────────────────────────────────
  Future<void> _submitSale() async {
    if (_selectedBatchId == null) {
      _showError('Please select a batch');
      return;
    }
    if (_quantity <= 0) {
      _showError('Please enter valid quantity');
      return;
    }
    if (_price <= 0) {
      _showError('Please enter valid price per egg');
      return;
    }

    final avail = _available[_selectedGrade] ?? 0;
    if (_quantity > avail) {
      _showError(
          'Only $avail Grade $_selectedGrade eggs are available. You entered $_quantity.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final dateStr = _selectedDate != null
          ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
          : null;

      final res = await _eggService.createEggSaleWithResponse(
        batchId: _selectedBatchId!,
        grade: _selectedGrade,
        eggsSold: _quantity,
        pricePerEgg: _price,
        saleDate: dateStr,
      );

      if (res != null && res.containsKey('__error')) {
        setState(() => _error = res['__error']);
      } else if (res != null && mounted) {
        _quantityController.clear();
        _priceController.clear();
        setState(() => _selectedDate = null);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                      'Sale recorded! $_quantity Grade $_selectedGrade eggs × Rs ${_price.toStringAsFixed(0)}'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() => _error = 'Failed to record sale. Please try again.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => setState(() => _error = msg);

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Egg Stock & Sales'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedBatchId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _loadingBatches
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Batch Selector ───────────────────────────────────────
                  _buildBatchSelector(),
                  const SizedBox(height: 16),

                  if (_selectedBatchId != null) ...[
                    if (_loadingData)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ))
                    else ...[
                      // ── Crate Quality Summary ──────────────────────────
                      _buildCrateSummaryCard(),
                      const SizedBox(height: 20),

                      // ── Stock Overview Cards ───────────────────────────
                      _buildSectionLabel('📦 Current Stock'),
                      const SizedBox(height: 10),
                      _buildStockOverview(),
                      const SizedBox(height: 20),

                      // ── Record Sale Form ───────────────────────────────
                      _buildSectionLabel('🧾 Record Sale'),
                      const SizedBox(height: 10),
                      _buildSaleForm(),
                      const SizedBox(height: 20),

                      // ── Recent Sales History ───────────────────────────
                      if (_sales.isNotEmpty) ...[
                        _buildSectionLabel('📋 Recent Sales'),
                        const SizedBox(height: 10),
                        _buildSalesHistory(),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ],

                  // ── Error ──────────────────────────────────────────────
                  if (_error != null) _buildErrorBox(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Batch Selector ───────────────────────────────────────────────────────
  Widget _buildBatchSelector() {
    return AppCard(
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          labelText: 'Select Batch',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon:
              Icon(Icons.inventory_2_outlined, color: AppTheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        value: _selectedBatchId,
        items: _batches.map((b) {
          return DropdownMenuItem<int>(
            value: b['batch_id'],
            child:
                Text('Batch #${b['batch_id']} — ${b['batch_type'] ?? 'N/A'}'),
          );
        }).toList(),
        onChanged: (v) {
          setState(() => _selectedBatchId = v);
          if (v != null) _loadData();
        },
      ),
    );
  }

  // ── Stock Overview ───────────────────────────────────────────────────────
  Widget _buildStockOverview() {
    final avail = _available;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: _grades.map((g) {
        final color = _gradeColors[g]!;
        final icon = _gradeIcons[g]!;
        final y =
            _yields.firstWhere((e) => e['grade'] == g, orElse: () => null);
        final produced = (y?['produced'] as num?)?.toInt() ?? 0;
        final sold = (y?['sold'] as num?)?.toInt() ?? 0;
        final available = avail[g] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(top: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Grade $g',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Text(
                '$available',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: available > 0 ? color : Colors.grey.shade400,
                ),
              ),
              Row(
                children: [
                  _miniStat('Prod', produced, Colors.grey.shade600),
                  const SizedBox(width: 8),
                  _miniStat('Sold', sold, Colors.orange.shade600),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _miniStat(String label, int val, Color color) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        Text(
          '$val',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  // ── Sale Form ────────────────────────────────────────────────────────────
  Widget _buildSaleForm() {
    final avail = _available[_selectedGrade] ?? 0;
    final color = _gradeColors[_selectedGrade]!;
    final validQty = _quantity > 0 && _quantity <= avail;
    final validPrice = _price > 0;
    final canSubmit = validQty && validPrice && !_submitting;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Grade chips ──────────────────────────────────────────────
          const Text(
            'Select Grade',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: _grades.map((g) {
              final isSelected = _selectedGrade == g;
              final gColor = _gradeColors[g]!;
              final gAvail = _available[g] ?? 0;
              return Expanded(
                child: GestureDetector(
                  onTap: gAvail > 0
                      ? () => setState(() {
                            _selectedGrade = g;
                            _error = null;
                          })
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? gColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? gColor : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          g,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (gAvail > 0
                                    ? gColor
                                    : Colors.grey.shade400),
                          ),
                        ),
                        Text(
                          '$gAvail avail',
                          style: TextStyle(
                            fontSize: 9,
                            color: isSelected
                                ? Colors.white70
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // ── Available badge ───────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.egg_outlined, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Grade $_selectedGrade — $avail eggs available',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Quantity ──────────────────────────────────────────────────
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity Sold *',
              hintText: 'Max: $avail eggs',
              prefixIcon: const Icon(Icons.format_list_numbered),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              errorText: _quantity > avail && _quantity > 0
                  ? 'Exceeds available ($avail)'
                  : null,
            ),
          ),

          const SizedBox(height: 12),

          // ── Price ─────────────────────────────────────────────────────
          TextField(
            controller: _priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price per Egg (PKR) *',
              hintText: 'e.g. 15.00',
              prefixIcon: const Icon(Icons.payments_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Date picker ───────────────────────────────────────────────
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _selectedDate == null
                        ? 'Sale Date (optional)'
                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    style: TextStyle(
                      color: _selectedDate == null
                          ? Colors.grey.shade500
                          : Colors.grey.shade800,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDate = null),
                      child: Icon(Icons.close,
                          size: 16, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Total amount banner ───────────────────────────────────────
          if (_quantity > 0 && _price > 0)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.12),
                    AppTheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_quantity eggs × Rs ${_price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '= Rs ${_totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

          // ── Submit button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: canSubmit ? _submitSale : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.receipt_long, color: Colors.white),
              label: Text(
                _submitting ? 'Recording...' : 'Record Sale',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit
                    ? AppTheme.primary
                    : Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: canSubmit ? 2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sales History ────────────────────────────────────────────────────────
  Widget _buildSalesHistory() {
    final recent = _sales.reversed.take(10).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sales History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_sales.length} records',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recent.map((sale) => _buildSaleRow(sale)),
        ],
      ),
    );
  }

  Widget _buildSaleRow(Map<dynamic, dynamic> sale) {
    final grade = sale['grade'] ?? '?';
    final sold = (sale['eggs_sold'] as num?)?.toInt() ?? 0;
    final price = (sale['price_per_egg'] as num?)?.toDouble() ?? 0.0;
    final total = sold * price;
    final date = sale['sale_date'] ?? '';
    final color = _gradeColors[grade] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                grade,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sold eggs × Rs ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          Text(
            'Rs ${total.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: Icon(Icons.close, color: Colors.red.shade400, size: 16),
          ),
        ],
      ),
    );
  }
}