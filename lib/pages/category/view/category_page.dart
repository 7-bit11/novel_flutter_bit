import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:novel_flutter_bit/pages/category/enum/category_enum.dart';
import 'package:novel_flutter_bit/pages/category/state/category_state.dart';
import 'package:novel_flutter_bit/pages/category/view_model/category_view_model.dart';
import 'package:novel_flutter_bit/pages/home/entry/novel_hot_entry.dart';
import 'package:novel_flutter_bit/route/route.gr.dart';
import 'package:novel_flutter_bit/tools/net_state_tools.dart';
import 'package:novel_flutter_bit/tools/padding_extension.dart';
import 'package:novel_flutter_bit/tools/size_extension.dart';
import 'package:novel_flutter_bit/widget/empty.dart';
import 'package:novel_flutter_bit/widget/image.dart';
import 'package:novel_flutter_bit/widget/loading.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:novel_flutter_bit/widget/pull_to_refresh.dart';
import 'package:pull_to_refresh_notification/pull_to_refresh_notification.dart';

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  late ThemeData _theme;
  // late CategoryViewModel _categoryViewModel;

  /// 分类列表
  final List<CategoryEnum> _categoryList = CategoryEnum.values;

  late int _currentIndex = 0;

  late Future<bool>? Function()? onRefresh;

  /// 跳转小说 站源 列表 页面
  _onToBookPage(String name) {
    context.router.push(BookRoute(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final categoryViewModel = ref.watch(categoryViewModelProvider);
    _theme = Theme.of(context);
    TextStyle style = Theme.of(context)
        .textTheme
        .bodyLarge!
        .copyWith(fontSize: 17, fontWeight: FontWeight.w300);
    return Scaffold(
      appBar: AppBar(title: const Text('分类列表')),
      body: SafeArea(
        child: DefaultTextStyle(
          style: style,
          child: PullToRefreshNotification(
            reachToRefreshOffset: 100,
            onRefresh: () async {
              if (onRefresh != null) {
                return await onRefresh!.call() ?? true;
              }
              return true;
            },
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: 10.verticalSpace),
              _buildCateGoryList(),
              _buildTitle(),
              PullToRefresh(
                backgroundColor: Theme.of(context).primaryColor,
                textColor: Colors.white,
              ),
              switch (categoryViewModel) {
                AsyncData(:final value) =>
                  Builder(builder: (BuildContext context) {
                    //LoggerTools.looger.e(value.netState);
                    final data =
                        NetStateTools.getWidget(value.netState, msg: value.msg);
                    if (data != null) {
                      return SliverToBoxAdapter(
                          child: Padding(
                              padding: const EdgeInsets.only(top: 100),
                              child: data));
                    }
                    final function =
                        ref.read(categoryViewModelProvider.notifier).onRefresh;
                    onRefresh = function;
                    return _buildSuccess(value: value);
                  }),
                AsyncError() => const SliverToBoxAdapter(child: EmptyBuild()),
                _ => const SliverToBoxAdapter(child: LoadingBuild()),
              }
            ]),
          ),
        ),
      ),
    );
  }

  /// 构建成功
  _buildSuccess({required CategoryState value}) {
    return SliverList.builder(
        itemCount: value.novelHot?.data?.length,
        itemBuilder: (context, index) {
          return _buildHotItem(value.novelHot?.data?[index],
              onTap: _onToBookPage);
        });
  }

  /// 构建标题
  SliverPadding _buildTitle() {
    return SliverPadding(
        padding: 10.padding,
        sliver: SliverToBoxAdapter(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('全网最热-分类', style: TextStyle(color: _theme.primaryColor)),
            const Icon(Icons.chevron_right)
          ],
        )));
  }

  /// 构建分类列表
  SliverPadding _buildCateGoryList() {
    return SliverPadding(
      padding: 10.padding,
      sliver: SliverToBoxAdapter(
        child: MasonryGridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: _categoryList.length,
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 8,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                _currentIndex = index;
                ref
                    .read(categoryViewModelProvider.notifier)
                    .setCurrentIndex(index);
                setState(() {});
              },
              child: _buildCateGoryItem(_categoryList[index]),
            );
          },
        ),
      ),
    );
  }

  ///  构建分类列表 item
  Widget _buildCateGoryItem(CategoryEnum categoryEnum) {
    Color color = const Color.fromARGB(255, 243, 243, 243);
    Color? textColor = _theme.textTheme.bodyLarge?.color?.withOpacity(.4);
    if (_categoryList[_currentIndex] == categoryEnum) {
      color = _theme.primaryColor;
      textColor = Colors.white;
    }
    return AnimatedContainer(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: color), //_theme.primaryColor.withOpacity()
      duration: Durations.short2,
      child: Text(categoryEnum.name,
          style: TextStyle(
              color: textColor, fontSize: 14, fontWeight: FontWeight.w400)),
    );
  }

  /// 热门item
  _buildHotItem(Datum? novelHot,
      {double height = 180, required void Function(String str) onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onTap.call(novelHot?.name ?? "");
      },
      child: SizedBox(
        height: height,
        child: Padding(
          padding: 10.padding,
          child: Row(
            children: [
              Flexible(
                  child: ExtendedImageBuild(
                      url: novelHot?.img ?? "", width: 120, height: height)),
              10.horizontalSpace,
              Expanded(
                flex: 2,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(novelHot?.name ?? "",
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20)),
                      5.verticalSpace,
                      Text("${novelHot?.author}/${novelHot?.type}",
                          style: const TextStyle(color: Colors.black54)),
                      5.verticalSpace,
                      Row(children: [
                        SvgPicture.asset(
                          'assets/svg/hot.svg',
                          width: 24,
                        ),
                        5.horizontalSpace,
                        Text(novelHot?.hot ?? "0",
                            style: TextStyle(
                                color: Theme.of(context).primaryColor)),
                      ]),
                      5.verticalSpace,
                      Flexible(
                        child: Text(novelHot?.desc ?? "",
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black54)),
                      )
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
