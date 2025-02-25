import "package:flutter/material.dart";
import "package:infinite_scroll_pagination/infinite_scroll_pagination.dart";
import "package:kaiteki/di.dart";
import "package:kaiteki/fediverse/services/bookmarks.dart";
import "package:kaiteki/model/pagination_state.dart";
import "package:kaiteki/preferences/theme_preferences.dart";
import "package:kaiteki/ui/shared/common.dart";
import "package:kaiteki/ui/shared/error_landing_widget.dart";
import "package:kaiteki/ui/shared/posts/post_widget.dart";
import "package:kaiteki/utils/extensions.dart";
import "package:kaiteki_core/kaiteki_core.dart";
import "package:sliver_tools/sliver_tools.dart";

class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarkPageState();
}

// HACK(Craftplacer): this widget cannot be used as-is, it lacks adapter capability checking
class _BookmarkPageState extends ConsumerState<BookmarksPage> {
  late final _controller = PagingController<String?, Post>(firstPageKey: null);
  ProviderSubscription<AsyncValue<PaginationState<Post>>>? _timeline;

  @override
  void initState() {
    super.initState();

    _controller.addPageRequestListener((pageKey) {
      final key = ref.read(currentAccountProvider)!.key;
      final provider = BookmarksServiceProvider(key);
      ref.read(provider.notifier).loadMore();
    });

    ref.listenManual(
      currentAccountProvider,
      (previous, next) {
        final provider = BookmarksServiceProvider(next!.key);

        _timeline?.close();
        _timeline = ref.listenManual(
          provider,
          (_, e) => _controller.value = e.getPagingState(""),
          fireImmediately: true,
        );
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverCrossAxisConstrained(
          maxCrossAxisExtent: 600,
          child: SliverPadding(
            padding: useCards ? const EdgeInsets.all(8) : EdgeInsets.zero,
            sliver: PagedSliverList<String?, Post>.separated(
              pagingController: _controller,
              builderDelegate: PagedChildBuilderDelegate<Post>(
                itemBuilder: (context, post, _) => _buildPost(context, post),
                animateTransitions: true,
                firstPageErrorIndicatorBuilder: (context) {
                  return Center(
                    child:
                        ErrorLandingWidget(_controller.error as TraceableError),
                  );
                },
                firstPageProgressIndicatorBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: centeredCircularProgressIndicator,
                ),
                noMoreItemsIndicatorBuilder: (context) {
                  final l10n = context.l10n;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        l10n.noMorePosts,
                        style:
                            TextStyle(color: Theme.of(context).disabledColor),
                      ),
                    ),
                  );
                },
              ),
              separatorBuilder: _buildSeparator,
            ),
          ),
        ),
      ],
    );
  }

  bool get useCards => ref.watch(usePostCards).value;

  Widget _buildPost(BuildContext context, Post post) {
    Widget widget = PostWidget(
      post,
      onOpen: () => context.showPost(post, ref),
    );

    if (useCards) {
      widget = Card(clipBehavior: Clip.antiAlias, child: widget);
    }

    return widget;
  }

  Widget _buildSeparator(BuildContext context, int index) {
    return useCards ? const SizedBox(height: 8) : const Divider(height: 1);
  }
}
