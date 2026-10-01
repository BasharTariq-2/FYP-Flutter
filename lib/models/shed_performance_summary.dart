class ShedPerformanceSummary {
  final int shedId;
  final String shedName;
  final int batchCount;
  final int activeBatchCount;
  final int totalHens;
  final int activeHens;
  final int cullingCount;
  final int isolationCount;
  final int eggSalesCount;
  final double eggSalesAmount;
  final int chickenSalesCount;
  final double chickenSalesAmount;
  final double feedUsageKg;
  final double salesRevenue;
  final bool isTopPerformer;

  ShedPerformanceSummary({
    required this.shedId,
    required this.shedName,
    required this.batchCount,
    required this.activeBatchCount,
    required this.totalHens,
    required this.activeHens,
    required this.cullingCount,
    required this.isolationCount,
    required this.eggSalesCount,
    required this.eggSalesAmount,
    required this.chickenSalesCount,
    required this.chickenSalesAmount,
    required this.feedUsageKg,
    required this.salesRevenue,
    required this.isTopPerformer,
  });

  factory ShedPerformanceSummary.fromJson(Map<String, dynamic> json) {
    return ShedPerformanceSummary(
      shedId: json['shed_id'] ?? 0,
      shedName: json['shed_name'] ?? 'Unknown',
      batchCount: json['batch_count'] ?? 0,
      activeBatchCount: json['active_batch_count'] ?? 0,
      totalHens: json['total_hens'] ?? 0,
      activeHens: json['active_hens'] ?? 0,
      cullingCount: json['culling_count'] ?? 0,
      isolationCount: json['isolation_count'] ?? 0,
      eggSalesCount: json['egg_sales_count'] ?? 0,
      eggSalesAmount: (json['egg_sales_amount'] ?? 0).toDouble(),
      chickenSalesCount: json['chicken_sales_count'] ?? 0,
      chickenSalesAmount: (json['chicken_sales_amount'] ?? 0).toDouble(),
      feedUsageKg: (json['feed_usage_kg'] ?? 0).toDouble(),
      salesRevenue: (json['sales_revenue'] ?? 0).toDouble(),
      isTopPerformer: json['is_top_performer'] ?? false,
    );
  }
}