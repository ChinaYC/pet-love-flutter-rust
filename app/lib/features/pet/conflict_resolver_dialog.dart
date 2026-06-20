import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConflictResolverDialog extends StatelessWidget {
  final String dataType;
  final String myValue;
  final String partnerValue;
  final VoidCallback onKeepMine;
  final VoidCallback onKeepPartner;
  final Function(String) onMerge;

  const ConflictResolverDialog({
    super.key,
    required this.dataType,
    required this.myValue,
    required this.partnerValue,
    required this.onKeepMine,
    required this.onKeepPartner,
    required this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController mergeController = TextEditingController();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: Offset(0.0, 10.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle,
                size: 40, color: Colors.orange),
            const SizedBox(height: 15),
            Text(
              '发现数据冲突',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '在断网期间，你们都修改了宠物的 [$dataType]，请选择要保留的数据：',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            // 我的数据
            InkWell(
              onTap: onKeepMine,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('保留我的: $myValue', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 10),
            // 对象的数据
            InkWell(
              onTap: onKeepPartner,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Text('保留对象的: $partnerValue', textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 10),
            // 手动合并
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: mergeController,
                    placeholder: '或输入新值',
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    if (mergeController.text.isNotEmpty) {
                      onMerge(mergeController.text);
                    }
                  },
                  child: const Text('合并'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
