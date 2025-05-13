import 'dart:convert';

import 'package:novel_flutter_bit/base/base_state.dart';
import 'package:novel_flutter_bit/entry/book_source_entry.dart';
import 'package:novel_flutter_bit/n_pages/home/view_model/home_view_model.dart';
import 'package:novel_flutter_bit/n_pages/search/entry/search_entry.dart';
import 'package:novel_flutter_bit/n_pages/search/state/search_state.dart';
import 'package:novel_flutter_bit/net/http_config.dart';
import 'package:novel_flutter_bit/net/new_novel_http.dart';
import 'package:novel_flutter_bit/tools/logger_tools.dart';
import 'package:novel_flutter_bit/tools/parse_source_rule.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'search_view_model.g.dart';

/// 搜索页
/// 时间 2024-9-29
/// 7-bit
@riverpod
class NewSearchViewModel extends _$NewSearchViewModel {
  SearchState searchState = SearchState();
  late List<BookSourceEntry>? _bookSourceEntry;
  @override
  Future<SearchState> build({required String searchKey}) async {
    LoggerTools.looger.d("NEW HomeViewModel init build");
    _initBookSourceEntry();
    _initData(searchKey: searchKey);
    return searchState;
  }

  /// 初始化书源
  _initBookSourceEntry() async {
    final homeViewModel = ref.read(homeViewModelProvider.notifier);
    _bookSourceEntry = homeViewModel.homeState.sourceEntry;
  }

  void _initData({
    required String searchKey,
  }) async {
    LoggerTools.looger.d("NewSearchViewModel _initData searchKey:$searchKey");
    List<SearchEntry> searchLis = [];
    if (_bookSourceEntry != null && _bookSourceEntry!.isNotEmpty) {
      for (var i = 0; i < (_bookSourceEntry?.length ?? 0); i++) {
        final itemList = await _getItemBookSourceEntry(
            searchKey: searchKey, bookSource: _bookSourceEntry![i]);
        searchLis.addAll(itemList);
        if (searchLis.isEmpty) {
          searchState.netState = NetState.emptyDataState;
          //state = AsyncData(searchState);
          continue;
        }
        searchState.searchList = searchLis;
        searchState.netState = NetState.dataSuccessState;
        state = AsyncData(searchState);
      }
    } else {
      LoggerTools.looger.e("书源为空无法查询");
      searchState.netState = NetState.emptyDataState;
      state = AsyncData(searchState);
    }
  }

  /// 获取书源单个查询出来的列表
  Future<List<SearchEntry>> _getItemBookSourceEntry({
    required BookSourceEntry bookSource,
    required String searchKey,
  }) async {
    try {
      Map map = ParseSourceRule.parseSearchUrl(
          searchKey: searchKey, searchUrl: bookSource.searchUrl ?? "");
      Map<String, dynamic>? params = {};
      String method = HttpConfig.get;
      if (map.containsKey('rule')) {
        Map rule = json.decode(map['rule']);
        if (rule.containsKey('method')) {
          final meth = rule['method'].toLowerCase();
          switch (meth) {
            case 'post':
              method = HttpConfig.post;
              break;
          }
        }
        if (rule.containsKey("body")) {
          params = parseQueryParams(rule['body']);
        } else if (rule.containsKey("webView")) {
          params = {'webView': true};
        }
      }

      final resultData = await NewNovelHttp().request(
          ParseSourceRule.parseUrl(
              bookSourceUrl: "${bookSource.bookSourceUrl}",
              parseSearchUrl: map['url']),
          method: method,
          params: params);
      final uint8List = resultData.data;
      resultData.data = ParseSourceRule.parseHtmlDecode(uint8List);
      final searchLis =
          _getSearchList(htmlData: resultData.data, bookSource: bookSource);
      return searchLis;
    } catch (e) {
      LoggerTools.looger.e("NewSearchViewModel _initData error:$e");
      return [];
    }
  }

  Map<String, dynamic>? parseQueryParams(String query) {
    // 将字符串按 '&' 分隔成键值对列表
    List<String> pairs = query.split('&');
    Map<String, String> params = {};

    // 遍历每个键值对
    for (String pair in pairs) {
      // 分割每个键值对成键和值
      List<String> parts = pair.split('=');
      if (parts.length == 2) {
        String key = Uri.decodeComponent(parts[0]);
        String value = Uri.decodeComponent(parts[1]);
        params[key] = value;
      }
    }

    return params;
  }

  /// 搜索列表
  /// 搜索结果 解析后i获取
  List<SearchEntry> _getSearchList({
    required String htmlData,
    required BookSourceEntry bookSource,
  }) {
    List<SearchEntry> searchList = [];

    /// 作者
    var author = ParseSourceRule.parseAllMatches(
        rootSelector: bookSource.ruleSearch!.bookList ?? "",
        rule: bookSource.ruleSearch!.author ?? "",
        htmlData: htmlData);

    /// 书url
    var bookUrl = ParseSourceRule.parseAllMatches(
        rootSelector: bookSource.ruleSearch!.bookList ?? "",
        rule: bookSource.ruleSearch!.bookUrl ?? "",
        htmlData: htmlData);

    /// 所有信息
    var bookAll = ParseSourceRule.parseAllMatches(
        //rootSelector: _bookSourceEntry.ruleSearch!.bookList ?? "",
        rule: bookSource.ruleSearch!.bookList ?? "",
        htmlData: htmlData);

    /// name 书名
    // final data3 = ParseSourceRule.parseAllMatches(
    //     rule: bookSourceEntry.ruleSearch!.coverUrl!, htmlData: htmlData);
    /// lastChapter 最新章节
    var lastChapter = ParseSourceRule.parseAllMatches(
        rootSelector: bookSource.ruleSearch!.bookList ?? "",
        rule: bookSource.ruleSearch!.lastChapter ?? "",
        htmlData: htmlData);

    /// name 书名
    var name = ParseSourceRule.parseAllMatches(
        rule: bookSource.ruleSearch!.name ?? "", htmlData: htmlData);

    /// 图片
    var coverUrl = ParseSourceRule.parseAllMatches(
        rootSelector: bookSource.ruleSearch!.bookList ?? "",
        rule: bookSource.ruleSearch!.coverUrl ?? "",
        htmlData: htmlData);

    /// 类型
    var kind = ParseSourceRule.parseAllMatches(
        rootSelector: bookSource.ruleSearch!.bookList ?? "",
        rule: bookSource.ruleSearch!.kind ?? "",
        htmlData: htmlData);
    // 如果 bookUrl 不为空，检查其他列表并调整长度
    // 如果 bookUrl 不为空，检查其他列表并调整长度
    if (bookUrl.isNotEmpty && bookUrl.any((url) => url != null)) {
      final length = bookUrl.length;

      // 确保其他列表不为空，如果为空则初始化为空数组
      author = author.isEmpty ? [] : author;
      bookAll = bookAll.isEmpty ? [] : bookAll;
      lastChapter = lastChapter.isEmpty ? [] : lastChapter;
      name = name.isEmpty ? [] : name;
      coverUrl = coverUrl.isEmpty ? [] : coverUrl;
      kind = kind.isEmpty ? [] : kind;
      // 补充空列表的长度
      author.length = author.isEmpty ? length : author.length;
      bookAll.length = bookAll.isEmpty ? length : bookAll.length;
      lastChapter.length = lastChapter.isEmpty ? length : lastChapter.length;
      name.length = name.isEmpty ? length : name.length;
      coverUrl.length = coverUrl.isEmpty ? length : coverUrl.length;
      kind.length = kind.isEmpty ? length : kind.length;

      author = List.generate(
          length, (index) => author.length > index ? author[index] : null);
      bookAll = List.generate(
          length, (index) => bookAll.length > index ? bookAll[index] : null);
      lastChapter = List.generate(length,
          (index) => lastChapter.length > index ? lastChapter[index] : null);
      name = List.generate(
          length, (index) => name.length > index ? name[index] : null);
      coverUrl = List.generate(
          length, (index) => coverUrl.length > index ? coverUrl[index] : null);
      kind = List.generate(
          length, (index) => kind.length > index ? kind[index] : null);
    }
    for (var i = 0; i < bookUrl.length; i++) {
      final bookurl =
          bookUrl[i]?.startsWith("http") ?? bookUrl[i] != "" ? true : false;
      final coverUrl1 =
          coverUrl[i]?.startsWith("http") ?? (coverUrl[i] != "") ? true : false;
      final coverUrlData = ParseSourceRule.parseUrl(
          bookSourceUrl: "${bookSource.bookSourceUrl}",
          parseSearchUrl: coverUrl[i] ?? "");
      final bookUrlData = ParseSourceRule.parseUrl(
          bookSourceUrl: "${bookSource.bookSourceUrl}",
          parseSearchUrl: bookUrl[i] ?? "");
      final searchEntry = SearchEntry(
          author: author[i],
          url: bookurl ? bookUrl[i] : bookUrlData,
          name: name[i],
          lastChapter: lastChapter[i],
          bookAll: bookAll[i],
          kind: kind[i],
          coverUrl: coverUrl1 ? coverUrl[i] : coverUrlData,
          bookSourceEntry: bookSource);
      // if (!searchList.any((d) => d.url == searchEntry.url && d.name != null)) {

      // }
      searchList.add(searchEntry);
    }
    return searchList;
  }
}
