import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/story_viewmodel.dart';

const _primaryColor = Color(0xFF4F46E5);

class CreateStoryView extends StatefulWidget {
  final File initialImage;

  const CreateStoryView({super.key, required this.initialImage});

  @override
  State<CreateStoryView> createState() => _CreateStoryViewState();
}

class _CreateStoryViewState extends State<CreateStoryView> {
  late File _currentImage;
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickAnotherImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) return;

    final file = File(image.path);
    final fileSize = await file.length();

    // Validasi ukuran maksimal 5MB
    if (fileSize > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ukuran gambar maksimal 5MB.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validasi format JPG, JPEG, PNG
    final extension = image.path.split('.').last.toLowerCase();
    const allowedExtensions = ['jpg', 'jpeg', 'png'];
    if (!allowedExtensions.contains(extension)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format tidak didukung. Gunakan gambar JPG atau PNG.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _currentImage = file;
    });
  }

  Future<void> _submitStory() async {
    final loginVm = context.read<LoginViewModel>();
    final userId = int.tryParse(loginVm.user?.id ?? '');

    if (userId == null || userId < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi telah berakhir. Silakan login kembali.'),
        ),
      );
      return;
    }

    final storyVm = context.read<StoryViewModel>();
    final success = await storyVm.uploadStory(
      userId: userId,
      imagePath: _currentImage.path,
      caption: _captionController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Story berhasil dibagikan!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      final error = storyVm.uploadError ?? 'Gagal mengunggah Story.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = context.watch<StoryViewModel>().isUploading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Preview Gambar
            Center(
              child: Image.file(
                _currentImage,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Top Bar: Tombol Kembali & Ganti Gambar
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol Batalkan / Tutup
                  IconButton(
                    onPressed: isUploading
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),

                  // Tombol Ganti Foto
                  TextButton.icon(
                    onPressed: isUploading ? null : _pickAnotherImage,
                    icon: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Ganti Foto',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black45,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Bar: Input Caption & Tombol Kirim
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        minLines: 1,
                        enabled: !isUploading,
                        decoration: const InputDecoration(
                          hintText: 'Tambahkan keterangan...',
                          hintStyle: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: isUploading ? null : _submitStory,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: isUploading
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Loading Overlay saat Upload Berlangsung
            if (isUploading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _primaryColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Mengunggah Story...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
