import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../models/reminder_item.dart';
import '../services/firebase_reminder_service.dart';
import '../services/reminder_download_service.dart';
import '../widgets/download_success_dialog.dart';

/// The three mutually-exclusive panels.
enum _ReminderView {
  productList,
  itemList,
  detail,
}

/// Flutter port of the Kodular "Reminder_sharing" screen.
class ReminderSharingScreen extends StatefulWidget {
  const ReminderSharingScreen({
    super.key,
    required this.headerTitle,
    required this.userName,

    // Firebase data is actually stored at the database root.
    this.firebaseBucket = '',

    this.bannerImageAsset,
    this.lottieAsset,
  });

  final String headerTitle;
  final String userName;
  final String firebaseBucket;

  final String? bannerImageAsset;
  final String? lottieAsset;

  @override
  State<ReminderSharingScreen> createState() =>
      _ReminderSharingScreenState();
}

class _ReminderSharingScreenState
    extends State<ReminderSharingScreen> {
  late final FirebaseReminderService _firebase =
      FirebaseReminderService(
    bucket: widget.firebaseBucket,
  );

  final ReminderDownloadService _downloader =
      ReminderDownloadService();

  _ReminderView _view = _ReminderView.productList;

  // ------------------------------------------------------------------
  // Product list
  // ------------------------------------------------------------------

  List<String> _allProducts = [];
  List<String> _filteredProducts = [];
  bool _loadingProducts = true;
  String _searchQuery = '';

  // ------------------------------------------------------------------
  // Literature list
  // ------------------------------------------------------------------

  String? _selectedProduct;
  List<ReminderItem> _items = [];
  bool _loadingItems = false;

  // ------------------------------------------------------------------
  // Detail
  // ------------------------------------------------------------------

  ReminderItem? _selectedItem;

  bool _downloading = false;
  double _downloadProgress = 0;

  String? _downloadedPath;

  bool _showDownloadedInfo = false;
  bool _showShareButton = false;

  // ------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // ------------------------------------------------------------------
  // Firebase loading
  // ------------------------------------------------------------------

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _loadingProducts = true;
      });
    }

    try {
      final products = await _firebase.getProductList();

      if (!mounted) return;

      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingProducts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load products: $e'),
        ),
      );
    }
  }

  Future<void> _selectProduct(String product) async {
    setState(() {
      _selectedProduct = product;
      _items = [];
      _loadingItems = true;
      _view = _ReminderView.itemList;
    });

    try {
      final items =
          await _firebase.getItemsForProduct(product);

      if (!mounted) return;

      setState(() {
        _items = items;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingItems = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load literature: $e'),
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // Detail
  // ------------------------------------------------------------------

  void _openDetail(ReminderItem item) {
    setState(() {
      _selectedItem = item;
      _downloadedPath = null;
      _showDownloadedInfo = false;
      _showShareButton = false;
      _view = _ReminderView.detail;
    });
  }

  // ------------------------------------------------------------------
  // Download
  // ------------------------------------------------------------------

  Future<void> _download() async {
    final item = _selectedItem;

    if (item == null || _downloading) {
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      final path = await _downloader.downloadImage(
        url: item.imageUrl,
        fileName: item.title,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        item.title,
        path,
      );

      if (!mounted) return;

      setState(() {
        _downloadedPath = path;
        _showDownloadedInfo = true;
        _showShareButton = true;
      });

      await showDialog(
        context: context,
        builder: (_) => DownloadSuccessDialog(
          lottieAsset: widget.lottieAsset,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------------
  // Share
  // ------------------------------------------------------------------

  Future<void> _share() async {
  final item = _selectedItem;
  final path = _downloadedPath;

  if (item == null || path == null) {
    return;
  }

  await Share.shareXFiles(
    [
      XFile(path),
    ],
    text: item.description,
  );
}

  // ------------------------------------------------------------------
  // Navigation
  // ------------------------------------------------------------------

  void _closeDetail() {
    setState(() {
      _selectedItem = null;
      _downloadedPath = null;
      _showDownloadedInfo = false;
      _showShareButton = false;
      _view = _ReminderView.itemList;
    });
  }

  void _closeItemList() {
    setState(() {
      _items = [];
      _selectedProduct = null;
      _view = _ReminderView.productList;
    });
  }

  bool _handleBackPressed() {
    switch (_view) {
      case _ReminderView.detail:
        _closeDetail();
        return false;

      case _ReminderView.itemList:
        _closeItemList();
        return false;

      case _ReminderView.productList:
        return true;
    }
  }

  // ------------------------------------------------------------------
  // Main UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _view == _ReminderView.productList,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPressed();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildTitleBanner(),
              _buildUserNameField(),

              if (_view != _ReminderView.detail)
                _buildImageBanner(),

              Expanded(
                child: _buildCurrentView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Header
  // ------------------------------------------------------------------

  Widget _buildTitleBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF50870),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Text(
        widget.headerTitle,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildUserNameField() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 12,
      ),
      child: IgnorePointer(
        child: TextField(
          enabled: false,
          controller: TextEditingController(
            text: widget.userName,
          ),
          style: const TextStyle(
            fontSize: 10,
          ),
          decoration: const InputDecoration(
            hintText: 'User Name',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _buildImageBanner() {
    if (widget.bannerImageAsset == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Image.asset(
        widget.bannerImageAsset!,
        fit: BoxFit.cover,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Current view
  // ------------------------------------------------------------------

  Widget _buildCurrentView() {
    switch (_view) {
      case _ReminderView.productList:
        return _buildProductListView();

      case _ReminderView.itemList:
        return _buildItemListView();

      case _ReminderView.detail:
        return _buildDetailView();
    }
  }

  // ------------------------------------------------------------------
  // PRODUCT LIST
  // ------------------------------------------------------------------

  Widget _buildProductListView() {
    if (_loadingProducts) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: const Color(0xFF2196F2),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search Product...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;

                  _filteredProducts = _allProducts
                      .where(
                        (product) => product
                            .toLowerCase()
                            .contains(
                              query.toLowerCase(),
                            ),
                      )
                      .toList();
                });
              },
            ),
          ),

          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredProducts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(
                      height: 1,
                      color: Colors.white24,
                    ),
                    itemBuilder: (context, index) {
                      final product =
                          _filteredProducts[index];

                      return ListTile(
                        tileColor:
                            const Color(0xFF2196F2),
                        title: Text(
                          product,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        onTap: () =>
                            _selectProduct(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // LITERATURE LIST
  //
  // Each Firebase record:
  //
  // [0] = Literature Name
  // [1] = Tagline
  // [2] = Cloudinary Image URL
  //
  // The Cloudinary image is displayed as the thumbnail.
  // ------------------------------------------------------------------

  Widget _buildItemListView() {
    if (_loadingItems) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Text('No items found'),
      );
    }

    return Container(
      color: const Color(0xFFFEEA3B),
      child: Column(
        children: [
          // Selected product header
          if (_selectedProduct != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                    ),
                    onPressed: _closeItemList,
                  ),

                  Expanded(
                    child: Text(
                      _selectedProduct!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.separated(
              itemCount: _items.length,

              separatorBuilder: (_, __) =>
                  const Divider(
                height: 1,
                color: Colors.black26,
              ),

              itemBuilder: (context, index) {
                final item = _items[index];

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),

                  // --------------------------------------------------
                  // ACTUAL CLOUDINARY IMAGE
                  // --------------------------------------------------

                  leading: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(6),

                    child: Container(
                      width: 65,
                      height: 65,
                      color: Colors.grey.shade200,

                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,

                              width: 65,
                              height: 65,

                              fit: BoxFit.cover,

                              loadingBuilder:
                                  (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress ==
                                    null) {
                                  return child;
                                }

                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },

                              errorBuilder:
                                  (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return const Icon(
                                  Icons.broken_image,
                                  size: 30,
                                  color: Colors.grey,
                                );
                              },
                            )
                          : const Icon(
                              Icons.image,
                              size: 30,
                              color: Colors.grey,
                            ),
                    ),
                  ),

                  // --------------------------------------------------
                  // LITERATURE NAME
                  // --------------------------------------------------

                  title: Text(
                    item.title,
                    style: const TextStyle(
                      color: Color(0xFF015747),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  // --------------------------------------------------
                  // TAGLINE
                  // --------------------------------------------------

                  subtitle: Padding(
                    padding:
                        const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description,
                      style: const TextStyle(
                        color: Color(0xFF046053),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),

                  // --------------------------------------------------
                  // FORWARD ARROW
                  // --------------------------------------------------

                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                  ),

                  onTap: () =>
                      _openDetail(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // DETAIL VIEW
  // ------------------------------------------------------------------

  Widget _buildDetailView() {
    final item = _selectedItem;

    if (item == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF2196F2),
            padding:
                const EdgeInsets.symmetric(
              vertical: 10,
            ),
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),

          // Full literature image
          if (item.imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Image.network(
                item.imageUrl,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder:
                    (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 96,
                ),
              ),
            ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Text(
              item.description,
              textAlign: TextAlign.center,
            ),
          ),

          // Download progress
          if (_downloading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),

          // Downloaded message
          if (_showDownloadedInfo)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(
                'The image has been downloaded to '
                'GameChanger folder in Download folder',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ),

          // Share button
          if (_showShareButton)
            Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 8,
              ),
              child: ElevatedButton.icon(
                onPressed: _share,
                icon: const Icon(
                  Icons.share,
                ),
                label: const Text(
                  'Share',
                ),
              ),
            ),

          // Download + Back buttons
          Padding(
            padding:
                const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _downloading
                          ? null
                          : _download,
                  icon: const Icon(
                    Icons.download,
                  ),
                  label: const Text(
                    'Download',
                  ),
                ),

                const SizedBox(width: 15),

                ElevatedButton.icon(
                  onPressed: _closeDetail,
                  icon: const Icon(
                    Icons.arrow_back,
                  ),
                  label: const Text(
                    'Back',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}