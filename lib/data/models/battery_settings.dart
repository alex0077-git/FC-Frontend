class BatterySettings {
  const BatterySettings({
    this.firstWarningPercent = 20,
    this.secondWarningPercent = 15,
    this.criticalPercent = 10,
    this.maxVoltage = 25.2,
    this.minVoltage = 18.0,
    this.lowVoltageThreshold = 21.0,
    this.criticalVoltageThreshold = 19.2,
    this.cellCount = 6,
  });

  final int firstWarningPercent;
  final int secondWarningPercent;
  final int criticalPercent;
  final double maxVoltage;
  final double minVoltage;
  final double lowVoltageThreshold;
  final double criticalVoltageThreshold;
  final int cellCount;

  BatterySettings copyWith({
    int? firstWarningPercent,
    int? secondWarningPercent,
    int? criticalPercent,
    double? maxVoltage,
    double? minVoltage,
    double? lowVoltageThreshold,
    double? criticalVoltageThreshold,
    int? cellCount,
  }) {
    return BatterySettings(
      firstWarningPercent: firstWarningPercent ?? this.firstWarningPercent,
      secondWarningPercent: secondWarningPercent ?? this.secondWarningPercent,
      criticalPercent: criticalPercent ?? this.criticalPercent,
      maxVoltage: maxVoltage ?? this.maxVoltage,
      minVoltage: minVoltage ?? this.minVoltage,
      lowVoltageThreshold: lowVoltageThreshold ?? this.lowVoltageThreshold,
      criticalVoltageThreshold:
          criticalVoltageThreshold ?? this.criticalVoltageThreshold,
      cellCount: cellCount ?? this.cellCount,
    );
  }
}
