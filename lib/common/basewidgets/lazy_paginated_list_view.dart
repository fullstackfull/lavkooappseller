import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/utill/dimensions.dart';

/// A paginated list that actually builds lazily.
///
/// The older [PaginatedListViewWidget] takes a pre-built `itemView`, so every
/// call site nested a `ListView.builder(shrinkWrap: true)` inside a
/// `SingleChildScrollView`. That combination defeats the builder entirely:
/// every loaded row is built, laid out and painted at once, and the whole list
/// re-lays-out on each notifyListeners. After a few pages of a busy order or
/// product list that is hundreds of live widgets.
///
/// This widget owns the scrollable itself, so cost stays proportional to what
/// is on screen. The loading indicator is the final row rather than a sibling.
class LazyPaginatedListView extends StatefulWidget {
  final ScrollController? scrollController;

  /// Called with the next page number when the user reaches the end.
  final Future<void> Function(int offset) onPaginate;

  /// Total number of records the server reports, used to know when to stop.
  final int? totalSize;

  /// The page currently loaded, as reported by the controller.
  final int? offset;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Records per page; must match what the API returns.
  final int pageSize;

  final EdgeInsetsGeometry? padding;
  final bool enabledPagination;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Optional header rendered above the first item inside the same scrollable,
  /// so filters and titles scroll with the list instead of pinning it.
  final Widget? header;

  const LazyPaginatedListView({
    super.key,
    required this.onPaginate,
    required this.totalSize,
    required this.offset,
    required this.itemCount,
    required this.itemBuilder,
    this.scrollController,
    this.pageSize = 10,
    this.padding,
    this.enabledPagination = true,
    this.shrinkWrap = false,
    this.physics,
    this.header,
  });

  @override
  State<LazyPaginatedListView> createState() => _LazyPaginatedListViewState();
}

class _LazyPaginatedListViewState extends State<LazyPaginatedListView> {
  late final ScrollController _controller;
  bool _ownsController = false;
  bool _isLoading = false;
  final Set<int> _requestedPages = <int>{1};

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _controller = widget.scrollController!;
    } else {
      _controller = ScrollController();
      _ownsController = true;
    }
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  int get _lastPage {
    final int? total = widget.totalSize;
    if (total == null || total <= 0) return 1;
    return (total / widget.pageSize).ceil();
  }

  int get _currentPage => widget.offset ?? 1;

  bool get _hasMore => widget.enabledPagination && _currentPage < _lastPage;

  void _onScroll() {
    if (!_controller.hasClients || _isLoading || !_hasMore) return;
    // Prefetch slightly before the very end so the next page is usually ready
    // by the time the user gets there.
    final double trigger = _controller.position.maxScrollExtent - 240;
    if (_controller.position.pixels >= trigger) {
      _paginate();
    }
  }

  Future<void> _paginate() async {
    final int next = _currentPage + 1;
    if (_isLoading || next > _lastPage || _requestedPages.contains(next)) return;

    _requestedPages.add(next);
    setState(() => _isLoading = true);
    try {
      await widget.onPaginate(next);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showHeader = widget.header != null;
    final bool showFooter = _hasMore || _isLoading;
    final int headerCount = showHeader ? 1 : 0;
    final int footerCount = showFooter ? 1 : 0;

    return ListView.builder(
      controller: _controller,
      padding: widget.padding ?? EdgeInsets.zero,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: headerCount + widget.itemCount + footerCount,
      itemBuilder: (BuildContext context, int index) {
        if (showHeader && index == 0) return widget.header!;

        final int itemIndex = index - headerCount;
        if (itemIndex < widget.itemCount) {
          return widget.itemBuilder(context, itemIndex);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
