import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum InventoryMutationType {
  add,
  update,
  delete,
  batchDelete,
  batchUpdateCategory,
}

abstract class AppMessage {
  const AppMessage({
    required this.topic,
    required this.createdAt,
  });

  final String topic;
  final DateTime createdAt;
}

class InventoryDataChangedMessage extends AppMessage {
  const InventoryDataChangedMessage({
    required this.mutationType,
    required DateTime occurredAt,
  }) : super(
          topic: 'inventory.data.changed',
          createdAt: occurredAt,
        );

  final InventoryMutationType mutationType;
}

class AppMessageQueue {
  final StreamController<AppMessage> _controller =
      StreamController<AppMessage>.broadcast();

  /// 功能：向全局消息队列发布一条应用级消息。
  /// 参数：message 为已封装好的业务消息对象。
  /// 返回值：无。
  /// 注意事项：用于显式跨页面通信，避免通过 provider 互相 watch 造成隐式联动。
  void publish(AppMessage message) {
    if (_controller.isClosed) return;
    _controller.add(message);
  }

  /// 功能：按消息类型订阅应用级消息流。
  /// 参数：T 为目标消息类型。
  /// 返回值：返回指定类型的广播流。
  /// 注意事项：调用方需自行管理 StreamSubscription 生命周期。
  Stream<T> ofType<T extends AppMessage>() {
    return _controller.stream.where((message) => message is T).cast<T>();
  }

  /// 功能：释放消息队列底层资源。
  /// 参数：无。
  /// 返回值：返回关闭队列的 Future。
  /// 注意事项：仅应由 ProviderScope 生命周期托管，不应在业务页面手动调用。
  Future<void> dispose() async {
    await _controller.close();
  }
}

final appMessageQueueProvider = Provider<AppMessageQueue>((ref) {
  final queue = AppMessageQueue();
  ref.onDispose(queue.dispose);
  return queue;
});
