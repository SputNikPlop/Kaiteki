import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:kaiteki/di.dart";
import "package:kaiteki/theming/default/extensions.dart";
import "package:kaiteki/ui/media_inspection/media.dart";
import "package:kaiteki/ui/media_inspection/screen.dart";
import "package:kaiteki/ui/share_sheet/share.dart";
import "package:kaiteki/ui/shared/common.dart";
import "package:kaiteki/ui/shared/icon_landing_widget.dart";
import "package:kaiteki/ui/shared/posts/attachments/attachment_widget.dart";
import "package:kaiteki/ui/shared/posts/avatar_widget.dart";
import "package:kaiteki/ui/shared/timeline/media_timeline_sliver.dart";
import "package:kaiteki/ui/shared/timeline/source.dart";
import "package:kaiteki/ui/shared/timeline/timeline.dart";
import "package:kaiteki/ui/user/user_panel.dart";
import "package:kaiteki/utils/extensions.dart";
import "package:kaiteki_core/kaiteki_core.dart";

const avatarSizeCompact = 72.0;
const avatarSize = 96.0;
const bannerHeight = 8.0 * 24.0;

class UserScreen extends ConsumerStatefulWidget {
  final String id;
  final User? user;

  const UserScreen({super.key, required this.id}) : user = null;

  UserScreen.fromUser({
    super.key,
    required User this.user,
  }) : id = user.id;

  @override
  ConsumerState<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen> {
  Future<User?>? _future;

  late StateProvider<bool> _showReplies;

  @override
  void initState() {
    super.initState();

    try {
      _future = widget.user.nullTransform(Future.value) ??
          ref.read(adapterProvider).getUserById(widget.id);
    } catch (e, s) {
      _future = Future.error(e, s);
    }
    _showReplies = StateProvider((_) => true);
  }

  Widget _buildAppBarUserName(User user) {
    return ListTile(
      title: Text.rich(
        user.renderDisplayName(context, ref),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
      subtitle: Text(
        user.handle.toString(),
        style: Theme
            .of(context)
            .textTheme
            .labelSmall,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = WindowWidthSizeClass.fromContext(context) <=
        WindowWidthSizeClass.compact;

    return FutureBuilder<User?>(
      future: _future,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final includeReplies = ref.watch(_showReplies);
        final theme = Theme.of(context);
        return FutureBuilder(
          future: (user?.bannerUrl ?? user?.avatarUrl)?.nullTransform(
                (url) =>
                ColorScheme.fromImageProvider(
                  provider: NetworkImage(url.toString()),
                  brightness: theme.brightness,
                ),
          ),
          builder: (context, snapshot) {
            return Theme(
              data: theme
                  .copyWith(colorScheme: snapshot.data)
                  .applyDefaultTweaks(),
              child: DefaultTabController(
                length: 3,
                child: Builder(
                  builder: (context) {
                    return isCompact
                        ? buildBodyCompact(context, user, includeReplies)
                        : buildBody(context, user, includeReplies);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    return ElevationOverlay.applySurfaceTint(
      Theme
          .of(context)
          .colorScheme
          .surface,
      Theme
          .of(context)
          .colorScheme
          .surfaceTint,
      2,
    );
  }

  Widget buildBody(BuildContext context, User? user, bool includeReplies) {
    const a = avatarSize * 0.5;
    final primaryButton = buildPrimaryButton(
      user,
      MediaQuery
          .sizeOf(context)
          .width < 840,
    );
    return Scaffold(
      backgroundColor: _getBackgroundColor(context),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton.filledTonal(
                onPressed: Navigator
                    .of(context)
                    .maybePop,
                icon: Icon(Icons.adaptive.arrow_back),
                tooltip: MaterialLocalizations
                    .of(context)
                    .backButtonTooltip,
              ),
            ),
            // https://m3.material.io/foundations/layout/canonical-layouts/supporting-pane#13c3c489-9cc7-4830-b44a-fe6c2d431c1f
            SizedBox(
              // HACK(Craftplacer): Material 3 advises to only show the supporting
              // pane when the screen hits the expanded layout class. Since the
              // recommended side pane width is 360dp, we use what is lower of
              // width and a third of the screen, so the content pane doesn't get
              // too squished.
              width: min(MediaQuery
                  .sizeOf(context)
                  .width / 3, 360,),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: a),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(16),
                            ),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _Banner.fromUser(user),
                            ),
                          ),
                        ),
                        if (user != null)
                          Positioned(
                            left: 16.0,
                            child: AvatarWidget(
                              user,
                              size: avatarSize,
                              onTap: () => _onViewAvatar(user),
                            ),
                          ),
                        Positioned(
                          left: 16.0 + avatarSize,
                          right: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (primaryButton != null) primaryButton,
                              const SizedBox(width: 8),
                              buildMenuButton(user),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 16),
                      UserPanel(user),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  child: ColoredBox(
                    color: Theme
                        .of(context)
                        .colorScheme
                        .surface,
                    child: Column(
                      children: [
                        Material(child: buildTabBar()),
                        Expanded(
                          child: Material(
                            child: buildTabBarView(includeReplies),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  MenuAnchor buildMenuButton(User<dynamic>? user) {
    return MenuAnchor(
      builder: (context, controller, _) {
        return IconButton.filledTonal(
          onPressed: user == null ? null : controller.open,
          icon: Icon(Icons.adaptive.more_rounded),
          tooltip: context.materialL10n.moreButtonTooltip,
        );
      },
      menuChildren: user == null ? [] : getMenuItems(user),
    );
  }

  List<Widget> getMenuItems(User<dynamic> user) {
    return [
      MenuItemButton(
        onPressed: user.url.nullTransform(
              (url) => () async => share(context, url),
        ),
        leadingIcon: Icon(Icons.adaptive.share_rounded),
        child: const Text("Share"),
      ),
    ];
  }

  Widget buildBodyCompact(BuildContext context,
      User? user,
      bool includeReplies,) {
    final primaryButton = buildPrimaryButton(
      user,
    );
    return Scaffold(
      backgroundColor: _getBackgroundColor(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          IconButton adaptiveIconButton({
            required Widget icon,
            required VoidCallback onPressed,
            required String tooltip,
          }) {
            return innerBoxIsScrolled
                ? IconButton(
              icon: icon,
              onPressed: onPressed,
              tooltip: tooltip,
              visualDensity: VisualDensity.standard,
            )
                : IconButton.filledTonal(
              icon: icon,
              onPressed: onPressed,
              tooltip: tooltip,
              visualDensity: VisualDensity.standard,
            );
          }

          final moreButton = buildMenuButton(user);
          return [
            SliverAppBar(
              automaticallyImplyLeading: false,
              leading: adaptiveIconButton(
                icon: Icon(Icons.adaptive.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations
                    .of(context)
                    .backButtonTooltip,
              ),
              backgroundColor: _getBackgroundColor(context),
              scrolledUnderElevation: 0,
              actions: [moreButton, kAppBarActionsSpacer],
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: !innerBoxIsScrolled
                    ? null
                    : user.nullTransform(_buildAppBarUserName),
              ),
              pinned: true,
              forceElevated: innerBoxIsScrolled,
              expandedHeight: bannerHeight + (avatarSize / 2),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: !innerBoxIsScrolled
                          ? const EdgeInsets.only(bottom: avatarSize / 2)
                          : EdgeInsets.zero,
                      child: _Banner.fromUser(user),
                    ),
                    if (user != null && !innerBoxIsScrolled)
                      Positioned(
                        left: 16.0,
                        bottom: 0,
                        child: AvatarWidget(
                          user,
                          size: avatarSize,
                          onTap: () => _onViewAvatar(user),
                        ),
                      ),
                    if (primaryButton != null)
                      Positioned(
                        left: 16.0 + avatarSize + 8,
                        right: 16.0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: primaryButton,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (user != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: UserPanel(user),
                ),
              ),
            CustomSliverPersistentHeader(
              child: Material(
                color: _getBackgroundColor(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildTabBar(),
                    const Divider(),
                  ],
                ),
              ),
            ),
          ];
        },
        body: Material(
          child: buildTabBarView(includeReplies),
        ),
      ),
    );
  }

  Widget buildTabBarView(bool includeReplies) {
    return TabBarView(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    FilterChip(
                      selected: includeReplies,
                      onSelected: (value) =>
                      ref
                          .read(_showReplies.notifier)
                          .state = value,
                      label: const Text("Replies"),
                    ),
                  ],
                ),
              ),
            ),
            TimelineSliver(
              UserTimelineSource(widget.id),
              includeReplies: includeReplies,
            ),
          ],
        ),
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(4),
              sliver: MediaTimelineSliver(
                UserTimelineSource(widget.id),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 256,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                tileBuilder: (context, item) {
                  return AttachmentWidget(attachment: item.$2);
                },
              ),
            ),
          ],
        ),
        const Center(
          child: IconLandingWidget(
            icon: Icon(Icons.star_outline_rounded),
            text: Text("Favorites is not implemented yet."),
          ),
        ),
      ],
    );
  }

  Widget buildTabBar() {
    return const TabBar(
      tabs: [
        Tab(text: "Posts"),
        Tab(text: "Media"),
        Tab(text: "Favorites"),
      ],
    );
  }

  Future<void> _onFollow(BuildContext context, User user) async {
    final adapter = ref.read(adapterProvider) as FollowSupport;

    final followState = user.state.follow;

    if (followState == null) return;

    User? updatedUser;

    switch (followState) {
      case UserFollowState.following:
        updatedUser = await adapter.unfollowUser(user.id) ??
            user.copyWith(
              state: user.state.copyWith(follow: UserFollowState.notFollowing),
            );
        break;

      case UserFollowState.notFollowing:
        updatedUser = await adapter.followUser(user.id) ??
            user.copyWith(
              state: user.state.copyWith(
                follow: user.flags?.isApprovingFollowers ?? false
                    ? UserFollowState.pending
                    : UserFollowState.following,
              ),
            );
        break;

      case UserFollowState.pending:
      // TODO(Craftplacer): Prompt to cancel follow request
        break;
    }

    setState(() {
      _future = Future.value(updatedUser);
    });
  }

  Widget? buildPrimaryButton(User? user, [bool small = false]) {
    final comfortableFilledButtonStyle = FilledButton.styleFrom(
      visualDensity: VisualDensity.comfortable,
    );

    if (user?.id == ref
        .watch(currentAccountProvider)
        ?.user
        .id) {
      if (small) {
        return IconButton.filled(
          onPressed: () {},
          icon: const Icon(Icons.edit_rounded),
          tooltip: context.l10n.editProfileButtonLabel,
        );
      }

      return FilledButton(
        onPressed: null,
        style: comfortableFilledButtonStyle,
        child: Text(context.l10n.editProfileButtonLabel),
      );
    }

    final followState = user?.state.follow;

    Future<void> onPressed() => _onFollow(context, user!);

    return switch (followState) {
      UserFollowState.following =>
      small
          ? IconButton.filledTonal(
        onPressed: onPressed,
        icon: const Icon(Icons.person_remove_rounded),
        tooltip: context.l10n.unfollowButtonLabel,
      )
          : FilledButton.tonal(
        onPressed: onPressed,
        style: comfortableFilledButtonStyle,
        child: Text(context.l10n.unfollowButtonLabel),
      ),
      UserFollowState.notFollowing =>
      small
          ? IconButton.filled(
        onPressed: onPressed,
        icon: const Icon(Icons.person_add_rounded),
        tooltip: context.l10n.followButtonLabel,
      )
          : FilledButton(
        onPressed: onPressed,
        style: comfortableFilledButtonStyle,
        child: Text(context.l10n.followButtonLabel),
      ),
      UserFollowState.pending =>
      small
          ? IconButton.filled(
        onPressed: onPressed,
        icon: const Icon(Icons.lock_clock_rounded),
        tooltip: context.l10n.pendingFollowRequestButtonLabel,
      )
          : FilledButton.tonal(
        onPressed: onPressed,
        style: comfortableFilledButtonStyle,
        child: Text(context.l10n.pendingFollowRequestButtonLabel),
      ),
      null => null,
    };
  }

  Future<void> _onViewAvatar(User user) async {
    final avatarUrl = user.avatarUrl!;

    await showDialog(
      context: context,
      builder: (_) {
        return MediaInspectionScreen(
          media: [
            RemoteMedia(
              avatarUrl,
              type: MediaType.image,
            ),
          ],
        );
      },
    );
  }

  Future<void> _onViewBanner(User user) async {
    final bannerUrl = user.bannerUrl!;

    await showDialog(
      context: context,
      builder: (_) {
        return MediaInspectionScreen(
          media: [
            RemoteMedia(
              bannerUrl,
              type: MediaType.image,
            ),
          ],
        );
      },
    );
  }
}

class CustomSliverPersistentHeader extends SingleChildRenderObjectWidget {
  const CustomSliverPersistentHeader({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCustomSliverPersistentHeader();
}

class _RenderCustomSliverPersistentHeader
    extends RenderSliverPinnedPersistentHeader {
  @override
  double get maxExtent =>
      child!.getMaxIntrinsicHeight(constraints.crossAxisExtent);

  @override
  double get minExtent =>
      child!.getMaxIntrinsicHeight(constraints.crossAxisExtent);
}

class _Banner extends StatelessWidget {
  final String? url;

  const _Banner(this.url);

  factory _Banner.fromUser(User? user) => _Banner(user?.bannerUrl?.toString());

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme
          .of(context)
          .colorScheme
          .surfaceVariant,
      child: const SizedBox.expand(),
    );

    final url = this.url;
    if (url == null) return placeholder;

    return Image.network(
      url,
      fit: BoxFit.cover,
      isAntiAlias: true,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
