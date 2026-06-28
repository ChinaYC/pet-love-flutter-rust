import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/app_message_queue.dart';
import '../../../../../src/rust/api/inventory.dart';

final inventoryMutationServiceProvider = Provider<InventoryMutationService>(
  (ref) => InventoryMutationService(ref),
);

class InventoryMutationService {
  InventoryMutationService(this._ref);

  final Ref _ref;

  /// 功能：新增囤货条目并在成功后广播数据变更。
  /// 参数：与库存新增字段一致。
  /// 返回值：返回新建条目的 id。
  /// 注意事项：仅在 Rust 写入成功后才会触发变更标记，避免账本误刷新。
  Future<String> addItem({
    required String name,
    required String category,
    required int purchaseDate,
    required int expirationDate,
    required double cost,
    String? imagePath,
  }) async {
    final id = await addInventoryItem(
      name: name,
      category: category,
      purchaseDate: purchaseDate,
      expirationDate: expirationDate,
      cost: cost,
      imagePath: imagePath,
    );
    _publishInventoryChanged(InventoryMutationType.add);
    return id;
  }

  /// 功能：更新囤货条目并在成功后广播数据变更。
  /// 参数：与库存更新字段一致。
  /// 返回值：无。
  /// 注意事项：调用方只需关心业务参数，不再手动触发刷新标记。
  Future<void> updateItem({
    required String id,
    required String name,
    required String category,
    required int purchaseDate,
    required int expirationDate,
    required double cost,
    String? imagePath,
  }) async {
    await updateInventoryItem(
      id: id,
      name: name,
      category: category,
      purchaseDate: purchaseDate,
      expirationDate: expirationDate,
      cost: cost,
      imagePath: imagePath,
    );
    _publishInventoryChanged(InventoryMutationType.update);
  }

  /// 功能：删除单条囤货数据并在成功后广播数据变更。
  /// 参数：id 为待删除条目主键。
  /// 返回值：无。
  /// 注意事项：虽然当前页面暂未使用，保留统一入口避免后续新增删除入口时漏打点。
  Future<void> deleteItem({required String id}) async {
    await deleteInventoryItem(id: id);
    _publishInventoryChanged(InventoryMutationType.delete);
  }

  /// 功能：批量删除囤货数据并在成功后广播数据变更。
  /// 参数：ids 为待删除条目 id 列表。
  /// 返回值：无。
  /// 注意事项：空列表校验应由调用方在进入服务前完成。
  Future<void> batchDeleteItems({required List<String> ids}) async {
    await batchDeleteInventoryItems(ids: ids);
    _publishInventoryChanged(InventoryMutationType.batchDelete);
  }

  /// 功能：批量修改囤货分类并在成功后广播数据变更。
  /// 参数：ids 为待更新条目列表，category 为目标分类。
  /// 返回值：无。
  /// 注意事项：该修改会影响账本分类统计，因此统一触发账本刷新。
  Future<void> batchUpdateCategory({
    required List<String> ids,
    required String category,
  }) async {
    await batchUpdateInventoryCategory(ids: ids, category: category);
    _publishInventoryChanged(InventoryMutationType.batchUpdateCategory);
  }

  /// 功能：向全局消息队列发送“囤货数据已变更”消息。
  /// 参数：mutationType 为本次成功写入的业务动作类型。
  /// 返回值：无。
  /// 注意事项：显式发布消息，不再依赖 provider 之间互相 watch 联动。
  void _publishInventoryChanged(InventoryMutationType mutationType) {
    _ref.read(appMessageQueueProvider).publish(
          InventoryDataChangedMessage(
            mutationType: mutationType,
            occurredAt: DateTime.now(),
          ),
        );
  }
}
