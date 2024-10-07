import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:novel_flutter_bit/base/base_state.dart';
import 'package:novel_flutter_bit/entry/book_source_entry.dart';
import 'package:novel_flutter_bit/n_pages/detail/entry/detail_book_entry.dart';
import 'package:novel_flutter_bit/n_pages/detail/state/detail_state.dart';
import 'package:novel_flutter_bit/net/new_novel_http.dart';
import 'package:novel_flutter_bit/tools/logger_tools.dart';
import 'package:novel_flutter_bit/tools/parse_source_rule.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'detail_view_model.g.dart';

/// 详情搜索
/// 时间 2024-10-1
/// 7-bit
@riverpod
class NewDetailViewModel extends _$NewDetailViewModel {
  /// 书源
  late BookSourceEntry _bookSourceEntry;

  final DetailState _detailState = DetailState();

  /// 排序顺序
  late bool reverse = false;

  @override
  Future<DetailState> build({
    required String detailUrl,
    required BookSourceEntry bookSource,
  }) async {
    LoggerTools.looger.d("NEW NewDetailViewModel init build");
    _bookSourceEntry = bookSource;
    _initData(detailUrl: detailUrl);
    return _detailState;
    // _bookSourceEntry = bookSourceEntry;
    // _initData(searchKey: searchKey, bookSourceEntry: bookSourceEntry);
  }

  void _initData({
    required String detailUrl,
  }) async {
    try {
      final resultData = await NewNovelHttp().request(detailUrl);
      final uint8List = resultData.data;
      resultData.data = ParseSourceRule.parseHtmlDecode(uint8List);
      final detailBook = _getSearchList(resultData.data);
      if (detailBook == null) {
        _detailState.netState = NetState.emptyDataState;
        state = AsyncData(_detailState);
        return;
      }
      _detailState.detailBookEntry = detailBook;
      _detailState.netState = NetState.dataSuccessState;
      state = AsyncData(_detailState);
      LoggerTools.looger.d(detailBook.toString());
    } catch (e) {
      LoggerTools.looger.e("NewSearchViewModel _initData error:$e");
      // searchState.netState = NetState.error403State;
      // state = AsyncData(searchState);
      SmartDialog.showToast(e.toString());
    }
  }

  /// 搜索列表
  /// 搜索结果 解析后i获取
  DetailBookEntry? _getSearchList(String htmlData) {
    try {
      /// 作者
      var author = ParseSourceRule.parseAllMatches(
          rule: _bookSourceEntry.ruleBookInfo!.author ?? "",
          htmlData: htmlData);

      /// url
      var coverUrl = ParseSourceRule.parseAllMatches(
          rule: _bookSourceEntry.ruleBookInfo!.coverUrl ?? "",
          htmlData: htmlData);

      /// 介绍
      var intro = ParseSourceRule.parseAllMatches(
          rule: _bookSourceEntry.ruleBookInfo!.intro ?? "", htmlData: htmlData);

      /// 最新章节
      var lastChapter = ParseSourceRule.parseAllMatches(
          rule: _bookSourceEntry.ruleBookInfo!.lastChapter ?? "",
          htmlData: htmlData);

      /// 书名
      var name = ParseSourceRule.parseAllMatches(
          rule: _bookSourceEntry.ruleBookInfo!.name ?? "", htmlData: htmlData);

      /// 章节列表
      var chapterList = ParseSourceRule.parseAllMatches(
          rootSelector: _bookSourceEntry.ruleToc!.chapterList ?? "",
          rule: _bookSourceEntry.ruleToc!.chapterUrl ?? "",
          htmlData: htmlData);

      chapterList = _getChapterList(
          detailUrl, bookSource.bookSourceUrl ?? "", chapterList);

      /// 章节列表
      var chapterName = ParseSourceRule.parseAllMatches(
          rootSelector: _bookSourceEntry.ruleToc!.chapterList ?? "",
          rule: _bookSourceEntry.ruleToc!.chapterName ?? "",
          htmlData: htmlData);

      List<Chapter> chapter = [];
      for (var i = 0; i < chapterList.length - chapterName.length; i++) {
        chapterName.insert(0, "开始阅读");
      }
      for (var i = 0; i < chapterList.length; i++) {
        final name = chapterName[i]?.replaceAll("\n", " ");
        chapter.add(Chapter(chapterUrl: chapterList[i], chapterName: name));
      }
      final detailAuthor = author.isNotEmpty ? author[0] : "";

      List<Chapter> uniqueList = [];
      Set<String> seenUrls = {}; // 用于记录已经出现过的 chapterUrl

      for (int i = chapter.length - 1; i >= 0; i--) {
        Chapter item = chapter[i];
        // 如果 seenUrls 中不包含当前的 chapterUrl，说明是第一次遇到该 url
        if (!seenUrls.contains(item.chapterUrl?.trim().toLowerCase())) {
          seenUrls.add(item.chapterUrl!.trim().toLowerCase());
          uniqueList.add(item);
        }
      }

      // 由于是从后往前添加的，需要再反转一次列表
      uniqueList = uniqueList.reversed.toList();

      DetailBookEntry detailBookEntry = DetailBookEntry(
        author: detailAuthor?.replaceAll("\n", " "),
        coverUrl: coverUrl.isNotEmpty ? coverUrl[0] : "暂无",
        intro: intro.isNotEmpty ? intro[0] : "暂无",
        lastChapter: lastChapter.isNotEmpty ? lastChapter[0] : "暂无",
        name: name.isNotEmpty ? name[0] : "暂无",
        chapter: uniqueList,
      );
      return detailBookEntry;
    } catch (e) {
      LoggerTools.looger.e("NewDetailViewModel _getSearchList error:$e");
      return null;
    }
  }

  List<String> _getChapterList(String url, String url1, List<String?> list) {
    List<String> resultList = [];

    for (var i = 0; i < list.length; i++) {
      if (!list[i]!.startsWith("/")) {
        // 去除baseUrl末尾的斜杠（如果有）
        if (url.endsWith('/')) {
          url = url.substring(0, url.length - 1);
        }
        // 如果relativeUrl以斜杠开头，则去除
        if (list[i]!.startsWith('/')) {
          list[i] = list[i]!.substring(1);
        }

        if (list[i]!.contains("javascript:Chapter")) {
          final map = extractChapterInfo(list[i]!);
          url = "${map['chapterId']}/${map['htmlFileName']}";
          if (list.length > i) {
            final uri = list[i - 1] ?? "";
            final split = uri.split("/");
            url = "${split[0]}/$url";
            resultList.add("$url1/$url");
            continue;
          }
        }
        resultList.add("$url/${list[i] ?? ""}");
      } else {
        // 去除baseUrl末尾的斜杠（如果有）
        if (url1.endsWith('/')) {
          url1 = url1.substring(0, url1.length - 1);
        }
        // 如果relativeUrl以斜杠开头，则去除
        if (list[i]!.startsWith('/')) {
          list[i] = list[i]!.substring(1);
        }

        resultList.add("$url1/${list[i] ?? ""}");
      }
    }
    return resultList;
  }

  /// 排序
  onReverse() {
    var data = _detailState.detailBookEntry?.chapter?.reversed.toList();
    _detailState.detailBookEntry?.chapter = data;
    reverse = !reverse;
    state = AsyncData(_detailState);
  }

  Map<String, String> extractChapterInfo(String input) {
    // 定义正则表达式
    var regex =
        RegExp("Chapter\\(\\'(\\d+)\\',\\'(.+?)\\'\\)", caseSensitive: false);
    // 使用正则表达式匹配输入字符串
    final Match? match = regex.firstMatch(input);

    if (match != null && match.groupCount == 2) {
      // 如果匹配成功，提取章节编号和HTML文件名
      return {'chapterId': match.group(1)!, 'htmlFileName': match.group(2)!};
    } else {
      // 如果没有匹配到，返回空的Map
      return {};
    }
  }
}
