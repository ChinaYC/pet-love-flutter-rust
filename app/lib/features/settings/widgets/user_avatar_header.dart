import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
      ref.read(userProfileNotifierProvider.notifier).updateProfile(avatarPath: image.path);
    }
  }

  void _editName(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('修改名字'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '请输入名字',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('确定'),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(userProfileNotifierProvider.notifier).updateProfile(name: newName);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileNotifierProvider);
    final themeColor = ref.watch(themeColorNotifierProvider);

    if (!isExpanded) {
      return GestureDetector(
        onTap: () => Scaffold.of(context).openDrawer(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Hero(
            tag: 'user_avatar',
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
                Hero(
                  tag: 'user_avatar',
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: themeColor,
                    backgroundImage: profile.avatarPath != null 
                        ? FileImage(File(profile.avatarPath!)) 
                        : null,
                    child: profile.avatarPath == null
                        ? const Icon(Icons.person, color: Colors.white, size: 30)
                        : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
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
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.edit, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
                const Text('点击头像或名字可修改', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
