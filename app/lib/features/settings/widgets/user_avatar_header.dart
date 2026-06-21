import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../user_profile_provider.dart';
import '../../../theme/theme_provider.dart';

class UserAvatarHeader extends ConsumerWidget {
  final bool isExpanded;

  const UserAvatarHeader({
    super.key,
    this.isExpanded = true,
  });

  Future<void> _pickImage(WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ref
          .read(userProfileNotifierProvider.notifier)
          .updateProfile(avatarPath: image.path);
    }
  }

  void _editName(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    AppDialog.show(
      context: context,
      title: const Text('修改名字'),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoTextField(
          controller: controller,
          placeholder: '请输入名字',
          autofocus: true,
          style: context.textTheme.bodyLarge,
        ),
      ),
      actions: [
        TextButton(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text('确定'),
          onPressed: () {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              ref
                  .read(userProfileNotifierProvider.notifier)
                  .updateProfile(name: newName);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileNotifierProvider);
    final themeColor = ref.watch(themeColorNotifierProvider);

    if (!isExpanded) {
      return Tooltip(
        message: '打开设置',
        child: InkWell(
          onTap: () => Scaffold.of(context).openDrawer(),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: themeColor,
              backgroundImage: profile.avatarPath != null
                  ? FileImage(File(profile.avatarPath!))
                  : null,
              child: profile.avatarPath == null
                  ? const Icon(Icons.favorite, color: Colors.white, size: 16)
                  : null,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickImage(ref),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: themeColor,
                  backgroundImage: profile.avatarPath != null
                      ? FileImage(File(profile.avatarPath!))
                      : null,
                  child: profile.avatarPath == null
                      ? const Icon(Icons.person, color: Colors.white, size: 30)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.adaptiveBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _editName(context, ref, profile.name),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.edit,
                          size: 14, color: context.theme.hintColor),
                    ],
                  ),
                ),
                Text('点击头像或名字可修改',
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: context.theme.hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
