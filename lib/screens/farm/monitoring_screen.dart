import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/batch_service.dart';
import '../../services/health_service.dart';
import '../../services/isolation_service.dart';
import '../../vaccinations/vaccination_tracking_screen.dart';
import '../../models/isolation.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';

class MonitoringScreen extends StatefulWidget {
  final int farmId;
  final int? preselectBatchId;
  final String? preselectMode;
  final int? preselectIsolationId;
  const MonitoringScreen({
    super.key,
    required this.farmId,
    this.preselectBatchId,
    this.preselectMode,
    this.preselectIsolationId,
  });

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final BatchService _batchService = BatchService();
  final HealthService _healthService = HealthService();
  final IsolationService _isolationService = IsolationService();
  final VaccinationService _vaccinationService = VaccinationService();

  // ── Batch selection ───────────────────────────────────────────────────────
  List<dynamic> _batches = [];
  int? _selectedBatchId;
  Map<String, dynamic>? _monitorInit;
  bool _loadingBatches = true;
  String? _error;

  // ── Monitoring Mode & Isolation Group ─────────────────────────────────────
  String _monitoringMode = 'active';
  List<dynamic> _activeIsolations = [];
  int? _selectedIsolationId;
  bool _loadingIsolations = false;

  // ── Session / flow ────────────────────────────────────────────────────────
  bool _isMonitoring = false;
  bool _isMeasuring = false;
  bool _isMonitoringComplete = false;
  String _sessionId = '';
  bool _isPaused = false;
  int? _lastProcessedLogId;
  Timer? _pollingTimer;

  // ── Sensor data ───────────────────────────────────────────────────────────
  Map<String, dynamic>? _latestData;

  // ── Progress ──────────────────────────────────────────────────────────────
  int _currentChick = 1;
  int _totalChicks = 0;
  int _healthyCount = 0;
  int _unhealthyCount = 0;
  int _isolatedCount = 0;

  // ── Isolation history ─────────────────────────────────────────────────────
  List<IsolationRecord> _isolationHistory = [];

  // ── Categorized chicks ────────────────────────────────────────────────────
  Map<String, dynamic>? _categorizedChicks;
  int _criticalCount = 0;

  // ── Vaccination summary ────────────────────────────────────────────────────
  Map<String, dynamic>? _vaccinationSummary;

  // ── Sensor offsets ────────────────────────────────────────────────────────
  final TextEditingController _weightOffsetController = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _tempOffsetController = TextEditingController(
    text: '0.0',
  );

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadBatches();
    _checkForActiveSessions();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Load batches ──────────────────────────────────────────────────────────
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
      });
      _applyPreselects();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBatches = false;
      });
    }
  }

  void _applyPreselects() {
    if (widget.preselectBatchId == null) return;
    final batchFound = _batches.any(
          (b) => b['batch_id'] == widget.preselectBatchId,
    );
    if (!batchFound) return;

    setState(() {
      _selectedBatchId = widget.preselectBatchId;
    });

    if (widget.preselectMode != null) {
      setState(() {
        _monitoringMode = widget.preselectMode!;
      });
    }

    if (_monitoringMode == 'isolated' && widget.preselectIsolationId != null) {
      _isolationService
          .getActiveIsolations(_selectedBatchId!)
          .then((list) {
        if (!mounted) return;
        final isoFound = list.any(
              (e) => e['isolation_id'] == widget.preselectIsolationId,
        );
        setState(() {
          _activeIsolations = list;
          if (isoFound) {
            _selectedIsolationId = widget.preselectIsolationId;
            final selectedGroup = list.firstWhere(
                  (e) => e['isolation_id'] == widget.preselectIsolationId,
            );
            _totalChicks = selectedGroup['hens_count'] ?? 0;
          }
        });
      })
          .catchError((_) {});
    } else if (_selectedBatchId != null) {
      final b = _batches.firstWhere(
            (e) => e['batch_id'] == _selectedBatchId,
        orElse: () => {},
      );
      if (b.isNotEmpty) {
        _totalChicks = b['active_hens'] ?? 0;
      }
    }

    if (_selectedBatchId != null) {
      _loadMonitorInit();
    }
  }

  Future<void> _loadMonitorInit() async {
    if (_selectedBatchId == null) return;
    final init = await _healthService.getMonitorInit(_selectedBatchId!);
    if (init.isNotEmpty && mounted) setState(() => _monitorInit = init);
    _loadIsolationHistory();
    _loadSensorOffsets(_selectedBatchId!);
  }

  Future<void> _loadSensorOffsets(int batchId) async {
    setState(() {});
    try {
      final offsets = await _healthService.getSensorOffsets(batchId);
      if (mounted) {
        setState(() {
          _weightOffsetController.text = (offsets['weight_offset'] ?? 0.0)
              .toString();
          _tempOffsetController.text = (offsets['temperature_offset'] ?? 0.0)
              .toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _weightOffsetController.text = '0.0';
          _tempOffsetController.text = '0.0';
        });
      }
    }
  }

  Future<void> _saveSensorOffsets(int batchId) async {
    final double weight = double.tryParse(_weightOffsetController.text) ?? 0.0;
    final double temp = double.tryParse(_tempOffsetController.text) ?? 0.0;
    try {
      await _healthService.updateSensorOffsets(batchId, weight, temp);
    } catch (e) {
      debugPrint('Error saving sensor offsets: $e');
    }
  }

  Future<void> _loadIsolationHistory() async {
    if (_selectedBatchId == null) return;
    try {
      final h = await _isolationService.getIsolationHistory(_selectedBatchId!);
      if (mounted) setState(() => _isolationHistory = h);
    } catch (_) {}
  }

  Future<void> _loadActiveIsolations() async {
    if (_selectedBatchId == null) return;
    setState(() {
      _loadingIsolations = true;
      _activeIsolations = [];
      _selectedIsolationId = null;
    });
    try {
      final list = await _isolationService.getActiveIsolations(
        _selectedBatchId!,
      );
      if (mounted) {
        setState(() {
          _activeIsolations = list;
          _loadingIsolations = false;
          if (_activeIsolations.isNotEmpty) {
            _selectedIsolationId = _activeIsolations.first['isolation_id'];
            final selectedGroup = _activeIsolations.firstWhere(
                  (e) => e['isolation_id'] == _selectedIsolationId,
            );
            _totalChicks = selectedGroup['hens_count'] ?? 0;
          } else {
            _totalChicks = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingIsolations = false;
        });
      }
    }
  }

  Future<void> _loadCategorizedChicks() async {
    if (_selectedBatchId == null) return;
    try {
      final data = await _healthService.getCategorizedChicks(_selectedBatchId!);
      if (data.isNotEmpty && mounted) {
        setState(() {
          _categorizedChicks = data;
          _criticalCount =
              (data['total_low_weight'] ?? 0) + (data['total_high_fever'] ?? 0);
        });
      }
    } catch (e) {
      debugPrint('❌ _loadCategorizedChicks Error: $e');
    }
  }

  // ── Load vaccination summary ──────────────────────────────────────────────
  Future<void> _loadVaccinationSummary() async {
    if (_selectedBatchId == null) return;
    try {
      final summary = await _vaccinationService.getVaccinationSummary(
        _selectedBatchId!,
      );
      if (summary.isNotEmpty && mounted) {
        setState(() => _vaccinationSummary = summary);
      }
    } catch (e) {
      debugPrint('❌ _loadVaccinationSummary Error: $e');
      if (mounted) setState(() => _vaccinationSummary = null);
    }
  }

  Future<void> _checkForActiveSessions() async {
    try {
      final sessions = await _healthService.getActiveSessions();
      if (sessions.isNotEmpty && mounted) {
        _showResumeDialog(sessions);
      }
    } catch (e) {
      debugPrint('Error checking active sessions: $e');
    }
  }

  void _showResumeDialog(List<dynamic> sessions) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Incomplete Monitoring Sessions'),
        content: const Text(
          'You have incomplete monitoring sessions. '
              'Would you like to resume one or start a new session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Start New Session'),
          ),
          ...sessions.map((session) {
            final int batchId = session['batch_id'] ?? -1;
            final int current = session['current_chick'] ?? 1;
            final int total = session['total_chicks'] ?? 0;
            final String status = session['status'] ?? 'unknown';
            return TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedBatchId = batchId;
                  _sessionId = session['session_id'] ?? '';
                  _totalChicks = total;
                  _currentChick = current;
                  _monitoringMode = session['mode'] ?? 'active';
                  _selectedIsolationId = session['isolation_id'];
                  _healthyCount = session['healthy_count'] ?? 0;
                  _unhealthyCount = session['unhealthy_count'] ?? 0;
                  _isolatedCount = session['isolated_count'] ?? 0;
                  _isPaused = session['status'] == 'paused';
                  _isMonitoring = true;
                  _isMeasuring = false;
                  _isMonitoringComplete = false;
                  _latestData = null;
                  _isolationHistory = [];
                  _categorizedChicks = null;
                  _lastProcessedLogId = null;
                });
                _loadIsolationHistory();
                _startAutomaticMonitoring();
              },
              child: Text('Resume Batch #$batchId ($current/$total $status)'),
            );
          }),
        ],
      ),
    );
  }

  // ── Start monitoring ──────────────────────────────────────────────────────
  Future<void> _startMonitoring() async {
    if (_selectedBatchId == null) return;
    setState(() => _isMeasuring = true);
    try {
      await _saveSensorOffsets(_selectedBatchId!);
      final session = await _healthService.startMonitoring(
        _selectedBatchId!,
        mode: _monitoringMode,
        isolationId: _monitoringMode == 'isolated'
            ? _selectedIsolationId
            : null,
      );
      if (session.isNotEmpty) {
        setState(() {
          _sessionId = session['session_id'] ?? '';
          _selectedBatchId = session['batch_id'] ?? _selectedBatchId;
          _totalChicks = session['total_chicks'] ?? _totalChicks;
          _currentChick = session['current_chick'] ?? 1;
          _healthyCount = session['healthy_count'] ?? 0;
          _unhealthyCount = session['unhealthy_count'] ?? 0;
          _isolatedCount = session['isolated_count'] ?? 0;
          _isPaused = session['status'] == 'paused';
          _isMonitoringComplete = session['status'] == 'completed';
          _isMonitoring = true;
          _isMeasuring = false;
          _latestData = null;
          _isolationHistory = [];
          _categorizedChicks = null;
          _lastProcessedLogId = null;
        });
        await _loadIsolationHistory();
        _startAutomaticMonitoring();
      } else {
        setState(() => _isMeasuring = false);
        _snack('Failed to start monitoring. Check hardware connection.');
      }
    } catch (e) {
      setState(() => _isMeasuring = false);
      _snack('Error: $e');
    }
  }

  // ── Polling loop ──────────────────────────────────────────────────────────
  void _startAutomaticMonitoring() async {
    _pollingTimer?.cancel();

    try {
      final initLog = await _healthService.getLatestHealth(_selectedBatchId!);
      if (initLog != null && initLog.isNotEmpty) {
        _lastProcessedLogId = initLog['log_id'];
        if (mounted) {
          setState(() {
            _latestData = initLog;
          });
        }
      }

      final initCount = await _healthService.getSessionChickCount(
        _selectedBatchId!,
        sessionId: _sessionId,
      );
      if (initCount != null && initCount.isNotEmpty && mounted) {
        setState(() {
          _currentChick = initCount['chick_count'] ?? _currentChick;
          _totalChicks = initCount['total_chicks'] ?? _totalChicks;
          _healthyCount = initCount['healthy_count'] ?? _healthyCount;
          _unhealthyCount = initCount['unhealthy_count'] ?? _unhealthyCount;
          _isolatedCount = initCount['isolated_count'] ?? _isolatedCount;
        });
      }
    } catch (e) {
      debugPrint('Error initializing auto-monitor: $e');
    }

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        timer,
        ) async {
      if (!_isMonitoring || _isMonitoringComplete) {
        timer.cancel();
        return;
      }
      if (_isPaused) return;

      try {
        // 1. Latest health reading
        final result = await _healthService.getLatestHealth(_selectedBatchId!);
        if (result.isNotEmpty) {
          final int? logId = result['log_id'];
          if (_lastProcessedLogId == null) {
            _lastProcessedLogId = logId;
            setState(() => _latestData = result);
          } else if (logId != null && logId > _lastProcessedLogId!) {
            _lastProcessedLogId = logId;
            setState(() => _latestData = result);
            final String status = result['status']?.toString() ?? 'Unknown';
            if (status.toLowerCase() == 'unhealthy') {
              _loadIsolationHistory();
            }
          }
        }

        // 2. Session chick count
        final countData = await _healthService.getSessionChickCount(
          _selectedBatchId!,
          sessionId: _sessionId,
        );
        if (countData.isNotEmpty) {
          setState(() {
            _currentChick = countData['chick_count'] ?? _currentChick;
            _totalChicks = countData['total_chicks'] ?? _totalChicks;
            _healthyCount = countData['healthy_count'] ?? _healthyCount;
            _unhealthyCount = countData['unhealthy_count'] ?? _unhealthyCount;
            _isolatedCount = countData['isolated_count'] ?? _isolatedCount;
          });

          if (countData['is_complete'] == true) {
            await _completeMonitoring();
          }
        }

        // 3. Categorized chicks + isolation history
        await _loadCategorizedChicks();
        await _loadIsolationHistory();
      } catch (e) {
        debugPrint('Error in polling loop: $e');
      }
    });
  }

  // ── Pause ─────────────────────────────────────────────────────────────────
  Future<void> _pauseMonitoring() async {
    if (_sessionId.isEmpty) return;
    setState(() => _isMeasuring = true);
    try {
      final success = await _healthService.pauseMonitoring(_sessionId);
      if (success) {
        setState(() {
          _isPaused = true;
          _isMeasuring = false;
        });
        _snack('Monitoring Paused');
      } else {
        setState(() => _isMeasuring = false);
        _snack('Failed to pause monitoring');
      }
    } catch (e) {
      setState(() => _isMeasuring = false);
      _snack('Error: $e');
    }
  }

  // ── Resume ────────────────────────────────────────────────────────────────
  Future<void> _resumeMonitoring() async {
    if (_sessionId.isEmpty) return;
    setState(() => _isMeasuring = true);
    try {
      final success = await _healthService.resumeMonitoring(_sessionId);
      if (success) {
        try {
          final latest = await _healthService.getLatestHealth(
            _selectedBatchId!,
          );
          _lastProcessedLogId = latest['log_id'];
        } catch (_) {}
        setState(() {
          _isPaused = false;
          _isMeasuring = false;
        });
        _snack('Monitoring Resumed');
      } else {
        setState(() => _isMeasuring = false);
        _snack('Failed to resume monitoring');
      }
    } catch (e) {
      setState(() => _isMeasuring = false);
      _snack('Error: $e');
    }
  }

  // ── Complete ──────────────────────────────────────────────────────────────
  Future<void> _completeMonitoring() async {
    _pollingTimer?.cancel();
    setState(() {
      _isMonitoringComplete = true;
      _isMeasuring = false;
    });
    if (!mounted) return;

    try {
      await _healthService.completeMonitoring(_sessionId);
    } catch (e) {
      debugPrint('Failed to call complete endpoint: $e');
    }

    // Refresh vaccination summary after monitoring is complete
    _loadVaccinationSummary();

    if (!mounted) return;

    final int total = _healthyCount + _unhealthyCount;
    final double healthyPct = total > 0 ? (_healthyCount / total * 100) : 0;
    final double unhealthyPct = total > 0 ? (_unhealthyCount / total * 100) : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('✅ Monitoring Complete'),
        content: Text(
          'Batch #$_selectedBatchId\n\n'
              'Total Monitored : $total / $_totalChicks\n'
              'Healthy          : $_healthyCount  (${healthyPct.toStringAsFixed(1)}%)\n'
              'Unhealthy        : $_unhealthyCount  (${unhealthyPct.toStringAsFixed(1)}%)\n'
              'Isolated         : $_isolatedCount',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_criticalCount > 0) {
                _showCriticalActionDialog();
              } else {
                _resetAndSelectNewBatch();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Critical action dialog ────────────────────────────────────────────────
  // ── Critical action dialog ────────────────────────────────────────────────
  void _showCriticalActionDialog() {
    if (!mounted) return;

    final int totalLowWeight = _categorizedChicks?['total_low_weight'] ?? 0;
    final int totalHighFever = _categorizedChicks?['total_high_fever'] ?? 0;
    final int totalHealthy = _categorizedChicks?['total_healthy'] ?? 0;
    final int totalOverlap = _categorizedChicks?['total_overlap'] ?? 0;
    final int totalCritical = _categorizedChicks?['total_critical'] ??
        ((totalLowWeight + totalHighFever) > totalOverlap
            ? (totalLowWeight + totalHighFever - totalOverlap)
            : (totalLowWeight + totalHighFever));

    int lowWeightCount = totalLowWeight;
    int highFeverCount = totalHighFever;
    int healthyCount= totalHealthy;
    String lowWeightAction = 'isolate';
    String highFeverAction = 'isolate';

    final TextEditingController lowController =
    TextEditingController(text: lowWeightCount.toString());
    final TextEditingController highController =
    TextEditingController(text: highFeverCount.toString());
    final TextEditingController healthyController =
    TextEditingController(text: _healthyCount.toString());
    bool isHandling = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Handle Critical Chicks',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary Box ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚖️ Low Weight Count: $totalLowWeight',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Action')),

                      const SizedBox(height: 4),
                      Text(
                        '🌡️ High Fever Count: $totalHighFever',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Action')
                      ),

                      Text(
                        '⚖Healthy: $totalHealthy',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),

                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Action')),

                      const SizedBox(height: 4),
                      const Divider(height: 12),
                      Text(
                        '🚨 Total Unique Critical Chicks: $totalCritical',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.red.shade900,
                        ),
                      ),
                      if (totalOverlap > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'ℹ️ Note: $totalOverlap chick(s) have BOTH low weight and high fever. Applying the same action (e.g., Isolate) to both will handle all $totalCritical unique critical chick(s) together without double-counting.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade900,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Low Weight Action Inputs ─────────────────────────────
                const Text(
                  'Low Weight Action',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: lowController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Count',
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (v) =>
                        lowWeightCount = int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: lowWeightAction,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'isolate', child: Text('Isolate')),
                          DropdownMenuItem(value: 'cull', child: Text('Cull')),
                          DropdownMenuItem(
                              value: 'none', child: Text('No action')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => lowWeightAction = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── High Fever Action Inputs ────────────────────────────
                const Text(
                  'High Fever Action',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: highController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Count',
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (v) =>
                        highFeverCount = int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 10),
                  //   Expanded(
                  //     child: DropdownButtonFormField<String>(
                  //       value: highFeverAction,
                  //       decoration: const InputDecoration(
                  //         border: OutlineInputBorder(),
                  //         contentPadding:
                  //         EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  //       ),
                  //       items: const [
                  //         DropdownMenuItem(
                  //             value: 'isolate', child: Text('Isolate')),
                  //         DropdownMenuItem(value: 'cull', child: Text('Cull')),
                  //         DropdownMenuItem(
                  //             value: 'none', child: Text('No action')),
                  //       ],
                  //       onChanged: (val) {
                  //         if (val != null) {
                  //           setModalState(() => highFeverAction = val);
                  //         }
                  //       },
                  //     ),
                  //   ),
                  ],
                ),
              ],
            ),
          ),
          // actions: [
          //   ElevatedButton(
          //     onPressed: isHandling
          //         ? null
          //         : () async {
          //       setModalState(() => isHandling = true);
          //       try {
          //         final res = await _healthService.handleCriticalChicks(
          //           sessionId: _sessionId,
          //           batchId: _selectedBatchId!,
          //           action: 'none',
          //           count: 0,
          //           reason:
          //           'Critical condition: Low weight / High fever detected during monitoring',
          //           lowWeightCount: lowWeightCount,
          //           highFeverCount: highFeverCount,
          //           lowWeightAction: lowWeightAction,
          //           highFeverAction: highFeverAction,
          //         );
          //
          //         if (context.mounted) {
          //           Navigator.pop(ctx);
          //         }
          //         final String msg = res['message'] ??
          //             'Handled critical chicks successfully.';
          //         _snack(msg);
          //         _resetAndSelectNewBatch();
          //       } catch (e) {
          //         setModalState(() => isHandling = false);
          //         if (context.mounted) {
          //           ScaffoldMessenger.of(context).showSnackBar(
          //             SnackBar(content: Text('Failed: ${e.toString()}')),
          //           );
          //         }
          //       }
          //     },
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.red,
          //       foregroundColor: Colors.white,
          //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          //       shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(10)),
          //     ),
          //     child: isHandling
          //         ? const SizedBox(
          //       width: 18,
          //       height: 18,
          //       child: CircularProgressIndicator(
          //         strokeWidth: 2,
          //         color: Colors.white,
          //       ),
          //     )
          //         : const Text('Apply Selected Actions',
          //         style: TextStyle(fontWeight: FontWeight.bold)),
          //   ),
          // ],
        ),
      ),
    );
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  void _resetAndSelectNewBatch() {
    _pollingTimer?.cancel();
    setState(() {
      _selectedBatchId = null;
      _currentChick = 1;
      _totalChicks = 0;
      _healthyCount = 0;
      _unhealthyCount = 0;
      _isolatedCount = 0;
      _isMonitoring = false;
      _isMeasuring = false;
      _isMonitoringComplete = false;
      _latestData = null;
      _monitorInit = null;
      _isolationHistory = [];
      _categorizedChicks = null;
      _isPaused = false;
      _sessionId = '';
      _lastProcessedLogId = null;
      _monitoringMode = 'active';
      _activeIsolations = [];
      _selectedIsolationId = null;
      _loadingIsolations = false;
      _criticalCount = 0;
      _vaccinationSummary = null;
    });
    _loadBatches();
    _snack('Select another batch');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('Smart Chick Monitoring')),
        body: _loadingBatches
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _isMonitoring
            ? _buildMonitoringPhase()
            : _buildSelectionPhase(),
      ),
    );
  }

  // ── SELECTION PHASE ───────────────────────────────────────────────────────
  Widget _buildSelectionPhase() {
    final standards = _monitorInit?['standards'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Batch to Monitor',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Available Batches',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedBatchId,
                    items: _batches
                        .map(
                          (b) => DropdownMenuItem<int>(
                        value: b['batch_id'],
                        child: Text(
                          'Batch #${b['batch_id']} - ${b['batch_type']} (${b['active_hens']} active)',
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final b = _batches.firstWhere((e) => e['batch_id'] == v);
                      setState(() {
                        _selectedBatchId = v;
                        if (_monitoringMode == 'isolated') {
                          _loadActiveIsolations();
                        } else {
                          _totalChicks = b['active_hens'] ?? 0;
                        }
                      });
                      _loadMonitorInit();
                      _loadVaccinationSummary();
                      _isolationService
                          .getActiveIsolations(_selectedBatchId!)
                          .then((list) {
                        if (mounted)
                          setState(() => _activeIsolations = list);
                      })
                          .catchError((_) {});
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Monitoring Mode',
                      border: OutlineInputBorder(),
                    ),
                    value: _monitoringMode,
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active Mode (Normal)'),
                      ),
                      DropdownMenuItem(
                        value: 'isolated',
                        child: Text('isolation'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _monitoringMode = val;
                        if (val == 'isolated') {
                          _loadActiveIsolations();
                        } else {
                          if (_selectedBatchId != null) {
                            final b = _batches.firstWhere(
                                  (e) => e['batch_id'] == _selectedBatchId,
                            );
                            _totalChicks = b['active_hens'] ?? 0;
                          }
                        }
                      });
                      _loadVaccinationSummary();
                    },
                  ),
                  if (_monitoringMode == 'isolated') ...[
                    const SizedBox(height: 16),
                    _loadingIsolations
                        ? const Center(child: CircularProgressIndicator())
                        : _activeIsolations.isEmpty
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No Low Weight / High Fever in this batch to monitor.',
                        style: TextStyle(
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                        : DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Select Isolation Group',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedIsolationId,
                      items: _activeIsolations
                          .map(
                            (iso) => DropdownMenuItem<int>(
                          value: iso['isolation_id'],
                          child: Text(
                            'Group #${iso['isolation_id']} (${iso['hens_count']} hens, ${iso['reason']})',
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final selectedGroup = _activeIsolations
                            .firstWhere((e) => e['isolation_id'] == v);
                        setState(() {
                          _selectedIsolationId = v;
                          _totalChicks = selectedGroup['hens_count'] ?? 0;
                        });
                      },
                    ),
                  ],
                  if (_monitorInit != null) ...[
                    const SizedBox(height: 20),
                    AppCard(
                      child: Column(
                        children: [
                          Text(
                            'Week ${_monitorInit!['current_week']} Growth Standards',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Divider(),
                          if (standards != null) ...[
                            _dataRow(
                              'Target Weight',
                              '${standards['min_weight']} – ${standards['max_weight']} g',
                            ),
                            _dataRow(
                              'Target Temp',
                              '${standards['min_temp']} – ${standards['max_temp']} °C',
                            ),
                          ] else
                            const Text(
                              'No standards defined for this week',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // ── Vaccination Summary Card ──────────────────────────────
                  if (_vaccinationSummary != null) ...[
                    const SizedBox(height: 20),
                    _buildVaccinationSummaryCard(),
                  ],
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.settings,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '⚙ Sensor Offsets (Optional)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _weightOffsetController,
                                decoration: const InputDecoration(
                                  labelText: 'Weight Offset (g)',
                                  border: OutlineInputBorder(),
                                  helperText: 'Default: 0.0',
                                ),
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  signed: true,
                                  decimal: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _tempOffsetController,
                                decoration: const InputDecoration(
                                  labelText: 'Temp Offset (°C)',
                                  border: OutlineInputBorder(),
                                  helperText: 'Default: 0.0',
                                ),
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  signed: true,
                                  decimal: true,
                                ),
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
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: 'Start Monitoring Session',
            onPressed:
            (_selectedBatchId != null &&
                (_monitoringMode != 'isolated' ||
                    (_monitoringMode == 'isolated' &&
                        _selectedIsolationId != null)))
                ? _startMonitoring
                : null,
            loading: _isMeasuring,
          ),
        ],
      ),
    );
  }

  // ── MONITORING PHASE ──────────────────────────────────────────────────────
  Widget _buildMonitoringPhase() {
    final status = _latestData?['status']?.toString() ?? 'Waiting...';
    final isHealthy = status.toLowerCase() == 'healthy';
    final standards = _monitorInit?['standards'];
    final checkedChicks = _healthyCount + _unhealthyCount;
    final progress = _totalChicks > 0
        ? (_currentChick / _totalChicks).clamp(0.0, 1.0)
        : 0.0;
    final int totalLowWeight = _categorizedChicks?['total_low_weight'] ?? 0;
    final int totalHighFever = _categorizedChicks?['total_high_fever'] ?? 0;



    final weightRaw = _latestData?['weight_grams'];
    final tempRaw = _latestData?['temperature_c'];
    final weightStr = weightRaw != null
        ? double.tryParse('$weightRaw')?.toStringAsFixed(1) ?? '$weightRaw'
        : '--';
    final tempStr = tempRaw != null
        ? double.tryParse('$tempRaw')?.toStringAsFixed(1) ?? '$tempRaw'
        : '--';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_criticalCount > 0 && _categorizedChicks != null)
            _buildCriticalDialog(),
          const SizedBox(height: 24),
          // ── Header ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chick #$_currentChick',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_currentChick / $_totalChicks',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),

          // ── Sensor card ───────────────────────────────────────────────
          AppCard(
            child: Column(
              children: [
                if (_isMeasuring) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Measuring... please wait',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _dataRow(
                    'Measured Weight',
                    '$weightStr g',
                    sub: standards != null
                        ? 'Range: ${standards['min_weight']}–${standards['max_weight']} g'
                        : null,
                  ),
                  const Divider(),
                  _dataRow(
                    'Measured Temp',
                    '$tempStr °C',
                    sub: standards != null
                        ? 'Range: ${standards['min_temp']}–${standards['max_temp']} °C'
                        : null,
                  ),
                  const Divider(),
                  _dataRow(
                    'Health Output',
                    _latestData?['status']?.toString() ?? 'Waiting...',
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Health Status:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        status == 'Waiting...'
                            ? 'WAITING...'
                            : status.toUpperCase(),
                        style: TextStyle(
                          color: status == 'Waiting...'
                              ? Colors.grey
                              : (isHealthy ? Colors.green : Colors.red),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  if (!isHealthy && status != 'Waiting...')
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Chick Isolated Automatically',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Counters ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _counterCard('Total', checkedChicks, Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _counterCard('Healthy', _healthyCount, Colors.green),
              ),
              const SizedBox(width: 8),
              //Expanded(
                //child: _counterCard('Unhealthy', _unhealthyCount, Colors.red),
              //),
              Expanded(
                child: _counterCard('Low Weight', totalLowWeight, Colors.red),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _counterCard('High Fever', totalHighFever, Colors.red),
              ),
              const SizedBox(width: 8),




              if (_monitoringMode == 'isolated') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _counterCard(
                    'Isolated',
                    _isolatedCount,
                    Colors.orange,
                  ),
                ),
              ],
            ],
          ),

          // ── Health summary bar ────────────────────────────────────────
          if (_healthyCount + _unhealthyCount > 0) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (_) {
                final int total = _healthyCount + _unhealthyCount;
                final double hPct = _healthyCount / total;
                final double uPct = _unhealthyCount / total;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: (_healthyCount * 100).round(),
                            child: Container(height: 14, color: Colors.green),
                          ),
                          if (_unhealthyCount > 0)
                            Expanded(
                              flex: (_unhealthyCount * 100).round(),
                              child: Container(height: 14, color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '✅ Healthy: ${(hPct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '❌ Unhealthy: ${(uPct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),











                        Text(
                          '⚖️ Low Weight: ${(uPct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '🌡️ High Fever : ${(uPct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 24),
          // ── Action buttons ────────────────────────────────────────────
          if (!_isMonitoringComplete) ...[
            if (_isPaused)
              PrimaryButton(
                text: 'Resume Monitoring',
                onPressed: _isMeasuring ? null : _resumeMonitoring,
                color: Colors.green,
              )
            else
              PrimaryButton(
                text: 'Pause Monitoring',
                onPressed: _isMeasuring ? null : _pauseMonitoring,
                color: Colors.orange,
              ),
          ] else ...[
            PrimaryButton(
              text: 'Select New Batch',
              onPressed: _resetAndSelectNewBatch,
              color: Colors.green,
            ),
          ],

          const SizedBox(height: 24),

          // ── Categorized chicks ────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildChickFrame(
                  title: '⚖️ Low Weight',
                  color: Colors.red,
                  chicks: _categorizedChicks != null
                      ? List<dynamic>.from(
                    _categorizedChicks!['low_weight_chicks'] ?? [],
                  )
                      : const [],
                  emptyMsg: 'No underweight chicks',
                  valueKey: 'weight_grams',
                  valueSuffix: 'g',
                  valueLabel: 'Weight',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChickFrame(
                  title: '🌡️High Fever',
                  color: Colors.red,
                  chicks: _categorizedChicks != null
                      ? List<dynamic>.from(
                    _categorizedChicks!['high_fever_chicks'] ?? [],
                  )
                      : const [],
                  emptyMsg: 'No high fever  chicks',
                  valueKey: 'temperature_c',
                  valueSuffix: '°C',
                  valueLabel: 'Temp',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChickFrame(
                  title: '🌡 Healthy',
                  color: Colors.green,
                  chicks: _categorizedChicks != null
                      ? List<dynamic>.from(
                    _categorizedChicks!['healthy_chicks'] ?? [],
                  )
                      : const [],
                  emptyMsg: 'No Healthy chicks',
                  valueKey: 'weight_grams',
                  valueSuffix: 'g',
                  valueLabel: 'Weight',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Isolation history ─────────────────────────────────────────
          const Text(
            'Isolation History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_isolationHistory.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No isolation records found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _isolationHistory.length,
              itemBuilder: (_, i) {
                final item = _isolationHistory[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: Text(
                      item.reason,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${item.isolatedOn.toLocal().toString().split(' ')[0]} '
                          '• By ${item.isolatedBy}',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCriticalDialog() {
    final int totalLowWeight = _categorizedChicks?['total_low_weight'] ?? 0;
    final int totalHighFever = _categorizedChicks?['total_high_fever'] ?? 0;
    final int totalHealthy = _categorizedChicks?['total_healthy'] ?? 0;
    final int totalOverlap = _categorizedChicks?['total_overlap'] ?? 0;
    final int totalCritical = _categorizedChicks?['total_critical'] ??
        (_criticalCount > 0 ? _criticalCount : totalLowWeight + totalHighFever + totalHealthy);

    return Card(
      color: Colors.red.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Critical Chicks Detected ($totalCritical)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('⚖️ Low Weight: $totalLowWeight'),
            Text('🌡️ High Fever: $totalHighFever'),
            Text('🌡 Healthy: $totalHealthy'),
            if (totalOverlap > 0) Text('ℹ️ Overlap: $totalOverlap'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCriticalActionDialog,
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('HANDLE CRITICAL CHICKS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ── Chick frame widget ────────────────────────────────────────────────────
  Widget _buildChickFrame({
    required String title,
    required Color color,
    required List<dynamic> chicks,
    required String emptyMsg,
    required String valueKey,
    required String valueSuffix,
    required String valueLabel,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Divider(height: 12),
            if (chicks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    emptyMsg,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...chicks.map((chick) {
                final int index = chick['chick_index'] ?? 0;
                final double? val = double.tryParse('${chick[valueKey]}');
                final double? min = double.tryParse('${chick['expected_min']}');
                final double? max = double.tryParse('${chick['expected_max']}');
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chick #$index',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$valueLabel: ${val?.toStringAsFixed(1) ?? '--'} $valueSuffix',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (min != null && max != null)
                        Text(
                          'Expected: ${min.toStringAsFixed(1)}–${max.toStringAsFixed(1)} $valueSuffix',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Vaccination summary card ────────────────────────────────────────────────
  Widget _buildVaccinationSummaryCard() {
    final summary = _vaccinationSummary!;
    final int ageDays = summary['age_days'] ?? 0;
    final String rawOverall = (summary['overall_status'] ?? 'Unknown').toString();
    final String alertMessage = (summary['alert_message'] ?? '').toString();
    final List vaccines = summary['vaccines'] ?? [];

    final String normOverall = rawOverall.trim().toLowerCase();
    final String normOverallColor = (summary['overall_status_color'] ?? summary['status_color'] ?? '').toString().trim().toLowerCase();

    Color statusColor;
    IconData statusIcon;

    if (normOverall == 'due' || normOverall.contains('due') || normOverall.contains('overdue') || normOverallColor == 'red') {
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
    } else if (normOverall == 'upcoming' || normOverall.contains('upcoming') || normOverall.contains('pending') || normOverallColor == 'orange') {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    } else if (normOverall == 'completed' || normOverall.contains('completed') || normOverall.contains('done') || normOverallColor == 'green') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.info_outline;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.vaccines, color: statusColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '💉 Vaccination Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  rawOverall,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Batch age
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(
                'Batch Age: $ageDays days',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Alert message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alertMessage,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vaccine list
          if (vaccines.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...vaccines.map((v) => _buildVaccineItem(v)),
          ] else ...[
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'No vaccines scheduled',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVaccineItem(Map<String, dynamic> vaccine) {
    final String name = vaccine['vaccine_name'] ?? 'Unknown';
    final String disease = vaccine['disease_name'] ?? '';
    final String method = vaccine['method'] ?? '';
    final String rawStatus = (vaccine['status'] ?? 'unknown').toString();
    final String normStatus = rawStatus.trim().toLowerCase();
    final String statusColorStr = (vaccine['status_color'] ?? '').toString().trim().toLowerCase();

    Color color;
    IconData icon;
    String statusLabel;

    if (normStatus == 'completed' || normStatus == 'done' || statusColorStr == 'green') {
      color = Colors.green;
      icon = Icons.check_circle;
      statusLabel = 'Completed';
    } else if (normStatus == 'due' || normStatus == 'overdue' || normStatus == 'pending' || statusColorStr == 'red') {
      color = Colors.red;
      icon = Icons.warning_amber_rounded;
      statusLabel = 'Due / Overdue';
    } else if (normStatus == 'upcoming' || statusColorStr == 'orange') {
      color = Colors.orange;
      icon = Icons.access_time;
      statusLabel = 'Upcoming';
    } else {
      color = Colors.grey;
      icon = Icons.help_outline;
      statusLabel = rawStatus;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                if (disease.isNotEmpty || method.isNotEmpty)
                  Text(
                    [disease, method].where((s) => s.isNotEmpty).join(' • '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _dataRow(String label, String value, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (sub != null)
            Text(
              sub,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _counterCard(String label, int count, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
