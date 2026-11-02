import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VisualAidScreen extends StatefulWidget {
  const VisualAidScreen({super.key});

  @override
  State<VisualAidScreen> createState() => _VisualAidScreenState();
}

class _VisualAidScreenState extends State<VisualAidScreen> {
  static const int _pageCount = 40;

  late final PageController _pageController;
  late final ScrollController _thumbnailController;

  late final List<TransformationController> _transformControllers;

  int _currentPage = 0;
  bool _showControls = true;

  // Tracks whether the current page is zoomed.
  bool _currentPageZoomed = false;

  List<String> get _pageAssets => List.generate(
        _pageCount,
        (index) =>
            'assets/images/VA_${(index + 1).toString().padLeft(3, '0')}.jpg',
      );

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _thumbnailController = ScrollController();

    _transformControllers = List.generate(
      _pageCount,
      (_) => TransformationController(),
    );

    _enterLandscapeFullScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCurrentThumbnail();
    });
  }

  Future<void> _enterLandscapeFullScreen() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _restoreSystemUI() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailController.dispose();

    for (final controller in _transformControllers) {
      controller.dispose();
    }

    _restoreSystemUI();

    super.dispose();
  }

  

  void _goToPage(int index) {
    if (index < 0 || index >= _pageCount) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _currentPageZoomed = false;
    });

    // Always start the newly selected page at 1×.
    _transformControllers[index].value =
        Matrix4.identity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerCurrentThumbnail();
    });
  }

  void _centerCurrentThumbnail() {
    if (!_thumbnailController.hasClients) return;

    const itemWidth = 92.0;

    final viewportWidth =
        _thumbnailController.position.viewportDimension;

    final target = (_currentPage * itemWidth) -
        (viewportWidth / 2) +
        (itemWidth / 2);

    final maxScroll =
        _thumbnailController.position.maxScrollExtent;

    final offset = target.clamp(0.0, maxScroll);

    _thumbnailController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _handleDoubleTap(
    BuildContext context,
    int pageIndex,
    TapDownDetails details,
  ) {
    final controller =
        _transformControllers[pageIndex];

    final currentScale =
        controller.value.getMaxScaleOnAxis();

    // Second double-tap resets the zoom.
    if (currentScale > 1.01) {
      controller.value = Matrix4.identity();

      setState(() {
        _currentPageZoomed = false;
      });

      return;
    }

    final renderBox =
        context.findRenderObject() as RenderBox;

    final localPosition =
        renderBox.globalToLocal(
      details.globalPosition,
    );

    final size = renderBox.size;

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final dx =
        center.dx - localPosition.dx;

    final dy =
        center.dy - localPosition.dy;

    final matrix = Matrix4.identity()
      ..translateByDouble(
        dx,
        dy,
        0.0,
        1.0,
      )
      ..scaleByDouble(
        2.5,
        2.5,
        1.0,
        1.0,
      );

    controller.value = matrix;

    setState(() {
      _currentPageZoomed = true;
    });
  }

  Widget _buildZoomablePage(
    BuildContext context,
    int index,
  ) {
    final asset = _pageAssets[index];

    final controller =
        _transformControllers[index];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,

          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
          },

          onDoubleTapDown: (details) {
            _handleDoubleTap(
              context,
              index,
              details,
            );
          },

          child: InteractiveViewer(
            transformationController:
                controller,

            minScale: 1.0,
            maxScale: 4.0,

            panEnabled: true,
            scaleEnabled: true,

            boundaryMargin:
                const EdgeInsets.all(200),

            onInteractionUpdate: (_) {
              final currentScale =
                  controller.value
                      .getMaxScaleOnAxis();

              final zoomed =
                  currentScale > 1.01;

              if (zoomed !=
                  _currentPageZoomed) {
                setState(() {
                  _currentPageZoomed =
                      zoomed;
                });
              }
            },

            onInteractionEnd: (_) {
              final currentScale =
                  controller.value
                      .getMaxScaleOnAxis();

              final zoomed =
                  currentScale > 1.01;

              if (zoomed !=
                  _currentPageZoomed) {
                setState(() {
                  _currentPageZoomed =
                      zoomed;
                });
              }
            },

            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,

              child: Center(
                child: Image.asset(
                  asset,

                  fit: BoxFit.contain,

                  cacheWidth: 2200,

                  errorBuilder:
                      (_, __, ___) {
                    return const Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 60,
                        ),

                        SizedBox(height: 12),

                        Text(
                          'Unable to load Visual Aid page',

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(int index) {
    final isSelected =
        index == _currentPage;

    return GestureDetector(
      onTap: () {
        // Selecting a thumbnail changes the page,
        // but deliberately keeps the strip visible.
        _goToPage(index);

        if (!_showControls) {
          setState(() {
            _showControls = true;
          });
        }
      },

      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),

        width: isSelected ? 88 : 78,
        height: isSelected ? 66 : 58,

        margin:
            const EdgeInsets.symmetric(
          horizontal: 5,
        ),

        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(6),

          border: Border.all(
            color: isSelected
                ? Colors.orange
                : Colors.white70,

            width:
                isSelected ? 3 : 1,
          ),

          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange
                        .withValues(alpha: 0.5),

                    blurRadius: 6,
                  ),
                ]
              : null,
        ),

        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(4),

          child: Stack(
            fit: StackFit.expand,

            children: [
              Image.asset(
                _pageAssets[index],

                fit: BoxFit.cover,

                cacheWidth: 180,

                errorBuilder:
                    (_, __, ___) {
                  return const ColoredBox(
                    color: Colors.black54,

                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                    ),
                  );
                },
              ),

              Positioned(
                left: 3,
                bottom: 3,

                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),

                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withValues(alpha: 0.7),

                    borderRadius:
                        BorderRadius.circular(3),
                  ),

                  child: Text(
                    '${index + 1}',

                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,

      child: Container(
        padding:
            const EdgeInsets.only(
          top: 8,
          bottom: 8,
        ),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,

            colors: [
              Colors.black
                  .withValues(alpha: 0.0),

              Colors.black
                  .withValues(alpha: 0.9),
            ],
          ),
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            SizedBox(
              height: 76,

              child: ListView.builder(
                controller:
                    _thumbnailController,

                scrollDirection:
                    Axis.horizontal,

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                ),

                itemCount:
                    _pageCount,

                itemBuilder:
                    (context, index) {
                  return _buildThumbnail(
                    index,
                  );
                },
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [
                IconButton(
                  onPressed:
                      _currentPage > 0
                          ? _previousPage
                          : null,

                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 32,
                  ),

                  tooltip:
                      'Previous page',
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),

                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withValues(alpha: 0.65),

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),

                  child: Text(
                    '${_currentPage + 1} / $_pageCount',

                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  onPressed:
                      _currentPage <
                              _pageCount - 1
                          ? _nextPage
                          : null,

                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 32,
                  ),

                  tooltip:
                      'Next page',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,

      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,

            colors: [
              Colors.black
                  .withValues(alpha: 0.75),

              Colors.black
                  .withValues(alpha: 0.0),
            ],
          ),
        ),

        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
              ),

              tooltip: 'Back',

              onPressed: () async {
                await _restoreSystemUI();

                if (!mounted) return;

                Navigator.of(context).pop();
              },
            ),

            const Expanded(
              child: Text(
                'Visual Aid',

                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),

              decoration:
                  BoxDecoration(
                color: Colors.black
                    .withValues(alpha: 0.6),

                borderRadius:
                    BorderRadius.circular(18),
              ),

              child: Text(
                '${_currentPage + 1} / $_pageCount',

                style:
                    const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,

              itemCount: _pageCount,

              onPageChanged:
                  _onPageChanged,

              // THE IMPORTANT PART:
              //
              // At 1×:
              // PageView handles horizontal swipe.
              //
              // When zoomed:
              // PageView is completely locked,
              // leaving InteractiveViewer to handle
              // pinch and pan.
              physics: _currentPageZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),

              itemBuilder:
                  (context, index) {
                return _buildZoomablePage(
                  context,
                  index,
                );
              },
            ),
          ),

          if (_showControls)
            _buildTopBar(),

          if (_showControls)
            _buildControls(),
        ],
      ),
    );
  }
}