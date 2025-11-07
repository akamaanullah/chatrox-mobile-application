import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';

class AllMediaScreen extends StatelessWidget {
  final List<Map<String, String>> mediaList;
  const AllMediaScreen({Key? key, required this.mediaList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
            decoration: BoxDecoration(
            gradient: AppTheme.mainGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          child: CommonAppBar(
            title: 'All Media',
            backgroundColor: Colors.transparent,
            textColor: Colors.white,
            elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Shared Media',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1e5955)),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: mediaList.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          insetPadding: const EdgeInsets.all(0),
                          child: _ImagePreviewSlider(
                            mediaList: mediaList,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        mediaList[index]['url']!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Image preview slider widget
class _ImagePreviewSlider extends StatefulWidget {
  final List<Map<String, String>> mediaList;
  final int initialIndex;
  const _ImagePreviewSlider({Key? key, required this.mediaList, required this.initialIndex}) : super(key: key);

  @override
  State<_ImagePreviewSlider> createState() => _ImagePreviewSliderState();
}

class _ImagePreviewSliderState extends State<_ImagePreviewSlider> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.mediaList.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Image.network(
                        widget.mediaList[index]['url']!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.broken_image, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 30,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.mediaList[index]['sender'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          top: 30,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        if (_currentIndex > 0)
          Positioned(
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 32),
              onPressed: () {
                if (_currentIndex > 0) {
                  _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
            ),
          ),
        if (_currentIndex < widget.mediaList.length - 1)
          Positioned(
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 32),
              onPressed: () {
                if (_currentIndex < widget.mediaList.length - 1) {
                  _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
            ),
          ),
        Positioned(
          bottom: 30,
          child: Text(
            '${_currentIndex + 1} / ${widget.mediaList.length}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
} 