import 'package:ap_common/callback/general_callback.dart';
import 'package:ap_common/models/course_notify_data.dart';
import 'package:ap_common/models/time_code.dart';
import 'package:ap_common/resources/ap_theme.dart';
import 'package:ap_common/scaffold/course_scaffold.dart';
import 'package:ap_common/utils/ap_localizations.dart';
import 'package:ap_common/utils/preferences.dart';
import 'package:ap_common/widgets/dialog_option.dart';
import 'package:ap_common_firebase/utils/firebase_analytics_utils.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:nsysu_ap/config/constants.dart';
import 'package:nsysu_ap/models/course_semester_data.dart';
import 'package:nsysu_ap/utils/app_localizations.dart';
import 'package:nsysu_ap/api/selcrs_helper.dart';

class CoursePage extends StatefulWidget {
  static const String routerName = "/course";

  @override
  CoursePageState createState() => CoursePageState();
}

class CoursePageState extends State<CoursePage> {
  ApLocalizations ap;

  CourseState state = CourseState.loading;

  TimeCodeConfig timeCodeConfig;

  CourseSemesterData semesterData;
  CourseData courseData;
  CourseNotifyData notifyData;

  List<String> items;
  int semesterIndex = 0;

  String customStateHint;
  String customHint;

  bool isOffline = false;
  bool isShowSearchButton = false;

  String defaultSemesterCode = '';

  String get courseNotifyCacheKey => '${SelcrsHelper.instance.username}'
      '_latest';

  @override
  void initState() {
    super.initState();
    FirebaseAnalyticsUtils.instance.setCurrentScreen("CoursePage", "course_page.dart");
    _getSemester();
    isShowSearchButton = Preferences.getBool(
      Constants.PREF_IS_SHOW_COURSE_SEARCH_BUTTON,
      true,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ap = ApLocalizations.of(context);
    return CourseScaffold(
      state: state,
      courseData: courseData,
      notifyData: notifyData,
      semesterIndex: semesterIndex,
      semesters: items,
      onSelect: (index) {
        this.semesterIndex = index;
        _getCourseTables();
      },
      onRefresh: _getCourseTables,
      customHint: isOffline ? ap.offlineCourse : null,
      isShowSearchButton: isShowSearchButton,
      enableNotifyControl: semesterData != null &&
          semesterData?.semesters[semesterIndex].value == defaultSemesterCode,
      courseNotifySaveKey: courseNotifyCacheKey,
      actions: <Widget>[
        PopupMenuButton<int>(
          onSelected: (int value) {
            switch (value) {
              case 1:
                setState(() {
                  isShowSearchButton = !isShowSearchButton;
                });
                Preferences.setBool(
                  Constants.PREF_IS_SHOW_COURSE_SEARCH_BUTTON,
                  isShowSearchButton,
                );
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Center(
                child: Text(
                  ap.settings,
                  style: TextStyle(color: ApTheme.of(context).greyText),
                ),
              ),
              value: -1,
              enabled: false,
            ),
            PopupMenuDivider(
              height: 10,
            ),
            PopupMenuItem(
              child: DialogOption(
                text: ApLocalizations.of(context).showSearchButton,
                check: isShowSearchButton,
                onPressed: null,
              ),
              value: 1,
              enabled: true,
            )
          ],
        ),
      ],
    );
  }

  Function(DioError) get _onFailure => (DioError e) {
        setState(() {
          if (courseData != null) {
            customHint = '${ap.offlineCourse}';
            state = CourseState.finish;
          } else {
            customStateHint = ApLocalizations.dioError(context, e);
            state = CourseState.error;
          }
        });
      };

  Function get _onError => (_) => setState(() => state = CourseState.error);

  void _getSemester() async {
    SelcrsHelper.instance.getCourseSemesterData(
      callback: GeneralCallback(
        onFailure: _onFailure,
        onError: _onError,
        onSuccess: (CourseSemesterData data) async {
          semesterData = data;
          RemoteConfig remoteConfig;
          try {
            remoteConfig = await RemoteConfig.instance;
            await remoteConfig.fetch(expiration: const Duration(seconds: 10));
            await remoteConfig.activateFetched();
            defaultSemesterCode =
                remoteConfig?.getString(Constants.DEFAULT_COURSE_SEMESTER_CODE);
            String rawTimeCodeConfig =
                remoteConfig?.getString(Constants.TIME_CODE_CONFIG);
            timeCodeConfig = TimeCodeConfig.fromRawJson(rawTimeCodeConfig);
            Preferences.setString(
                Constants.DEFAULT_COURSE_SEMESTER_CODE, defaultSemesterCode);
            Preferences.setString(
                Constants.TIME_CODE_CONFIG, rawTimeCodeConfig);
          } catch (exception) {
            defaultSemesterCode = Preferences.getString(
              Constants.DEFAULT_COURSE_SEMESTER_CODE,
              '${Constants.DEFAULT_YEAR}${Constants.DEFAULT_SEMESTER}',
            );
            timeCodeConfig = TimeCodeConfig.fromRawJson(
              Preferences.getString(
                Constants.TIME_CODE_CONFIG,
                '{  "timeCodes":[{"title":"A",         "startTime": "7:00"         ,"endTime": "7:50"        },{       "title":"1",         "startTime": "8:10"         ,"endTime": "9:00"        },{       "title":"2",         "startTime": "9:10"         ,"endTime": "10:00"        },{       "title":"3",         "startTime": "10:10"         ,"endTime": "11:00"        },{       "title":"4",         "startTime": "11:10"         ,"endTime": "12:00"        },{       "title":"B",         "startTime": "12:10"         ,"endTime": "13:00"        },{       "title":"5",         "startTime": "13:10"         ,"endTime": "14:00"        },{       "title":"6",         "startTime": "14:10"         ,"endTime": "15:00"        },{       "title":"7",         "startTime": "15:10"         ,"endTime": "16:00"        },{       "title":"8",         "startTime": "16:10"         ,"endTime": "17:00"        },{       "title":"9",         "startTime": "17:10"         ,"endTime": "18:00"        },{       "title":"C",         "startTime": "18:20"         ,"endTime": "19:10"        },{       "title":"D",         "startTime": "19:15"         ,"endTime": "20:05"        },{       "title":"E",         "startTime": "20:10"         ,"endTime": "21:00"        },{       "title":"F",         "startTime": "21:05"         ,"endTime": "21:55"        }] }',
              ),
            );
          }
          items = [];
          var i = 0;
          semesterData.setDefault(defaultSemesterCode);
          semesterData.semesters.forEach((option) {
            items.add(parser(option.text));
            if (option.value == defaultSemesterCode) semesterIndex = i;
            i++;
          });
          _getCourseTables();
        },
      ),
    );
  }

  String parser(String text) {
    final app = AppLocalizations.of(context);
    if (text.length == 4) {
      String lastCode = text.substring(3);
      String last = '';
      switch (lastCode) {
        case '0':
          last = app.continuingSummerEducationProgram;
          break;
        case '1':
          last = app.fallSemester;
          break;
        case '2':
          last = app.springSemester;
          break;
        case '3':
          last = app.summerSemester;
          break;
      }
      String first;
      if (AppLocalizations.locale.languageCode == 'en') {
        int year = int.parse(text.substring(0, 3));
        year += 1911;
        first = '$year~${year + 1}';
      } else
        first = '${text.substring(0, 3)}${app.courseYear}';
      return '$first $last';
    } else
      return text;
  }

  _getCourseTables() async {
    if (semesterData == null) {
      _getSemester();
      return;
    }
    notifyData = CourseNotifyData.load(courseNotifyCacheKey);
    SelcrsHelper.instance.getCourseData(
      username: SelcrsHelper.instance.username,
      timeCodeConfig: timeCodeConfig,
      semester: semesterData.semesters[semesterIndex].value,
      callback: GeneralCallback(
        onFailure: _onFailure,
        onError: _onError,
        onSuccess: (CourseData data) {
          courseData = data;
          if (mounted && courseData != null)
            setState(() {
              if (courseData?.courseTables == null)
                state = CourseState.empty;
              else
                state = CourseState.finish;
            });
        },
      ),
    );
  }
}
