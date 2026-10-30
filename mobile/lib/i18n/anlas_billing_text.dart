/// Only for a selected account whose explicit profile method is relay.
({String actualUnknown, String reference, String noSharedOpus})
    relayAnlasBillingText(Object? language, int? amount) {
  final value = amount?.toString() ?? '?';
  return (
    actualUnknown: '中转实际扣费：未知',
    reference: '官方无订阅优惠参考：$value Anlas（估算，非中转账单）',
    noSharedOpus: '官方 Opus 优惠不与独立中转账号共享。'
  );
}

String anlasPreviewHeading(Object? language, {required bool official}) =>
    official ? '生成前官方报价（非实际扣费）' : '生成前估算（非实际扣费）';
