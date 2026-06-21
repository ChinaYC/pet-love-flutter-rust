import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/theme_provider.dart';

class PetProfileForm extends StatefulWidget {
  const PetProfileForm({super.key});

  @override
  State<PetProfileForm> createState() => _PetProfileFormState();
}

class _PetProfileFormState extends State<PetProfileForm> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _bodyType =
      'normal'; // 自动计算出的体型: 'underweight', 'normal', 'overweight'

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  /// 核心计算逻辑：根据体重和年龄评估体型
  /// 遵循“首尾夹击法”，此方法既在 UI 变更时调用，也在最终保存前被强制调用
  String _reckonBodyType(double weight, int age) {
    if (weight <= 0 || age < 0) return 'unknown';

    // 简化的虚拟逻辑：假设成年猫（>=1岁），>6kg 算超重，<3kg 算偏瘦
    if (age >= 1) {
      if (weight > 6.0) return 'overweight';
      if (weight < 3.0) return 'underweight';
      return 'normal';
    } else {
      // 幼猫
      if (weight > 4.0) return 'overweight';
      return 'normal';
    }
  }

  /// 当输入框内容变化时，尝试更新 UI 显示
  /// 警告：严禁只依赖此处更新状态！保存时必须进行数据兜底重算。
  void _onInputChanged() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final age = int.tryParse(_ageController.text) ?? 0;
    setState(() {
      _bodyType = _reckonBodyType(weight, age);
    });
  }

  /// 最终的保存入库/网络请求函数
  Future<void> saveFormData() async {
    // 1. 获取用户输入
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final age = int.tryParse(_ageController.text) ?? 0;

    // ==========================================
    // 防御性编程：强制兜底重算 (Data Persistency Interception)
    // ==========================================
    // 强制在打包数据前一刻，重新调用一次核心的计算/校验方法。
    // 完美防御历史旧数据回显未触发点击事件、模板填充跳过计算、异步状态滞后等导致的数据不一致问题。
    final finalReckonedBodyType = _reckonBodyType(weight, age);

    if (weight <= 0 || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的体重和年龄。')),
      );
      return;
    }

    final payload = {
      'weight': weight,
      'age': age,
      'bodyType': finalReckonedBodyType, // 使用强制重算后的值，不直接使用状态 _bodyType
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    debugPrint("准备通过 FFI 传递给 Rust: ${jsonEncode(payload)}");

    // 模拟调用 Rust FFI:
    // await api.savePetProfile(payload: jsonEncode(payload));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存成功！最终计算体型: $finalReckonedBodyType')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      color: context.adaptiveSecondaryBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🐾 宠物档案',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CupertinoTextField(
              controller: _weightController,
              placeholder: '体重 (kg)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _onInputChanged(),
              style: theme.textTheme.bodyLarge,
              placeholderStyle:
                  theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
              prefix: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(CupertinoIcons.speedometer,
                      color: theme.iconTheme.color)),
            ),
            const SizedBox(height: 15),
            CupertinoTextField(
              controller: _ageController,
              placeholder: '年龄 (岁)',
              keyboardType: TextInputType.number,
              onChanged: (_) => _onInputChanged(),
              style: theme.textTheme.bodyLarge,
              placeholderStyle:
                  theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
              prefix: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(CupertinoIcons.calendar,
                      color: theme.iconTheme.color)),
            ),
            const SizedBox(height: 20),
            // UI 上展示的体型，仅供参考，保存时会被兜底逻辑覆盖计算
            Text('系统预估体型: $_bodyType',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: saveFormData,
                child: const Text('保存档案'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
