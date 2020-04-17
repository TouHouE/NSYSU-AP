import 'package:ap_common/callback/general_callback.dart';
import 'package:ap_common/resources/ap_theme.dart';
import 'package:flutter/material.dart';
import 'package:nsysu_ap/models/tuition_and_fees.dart';
import 'package:nsysu_ap/utils/app_localizations.dart';
import 'package:nsysu_ap/utils/firebase_analytics_utils.dart';
import 'package:nsysu_ap/api/helper.dart';
import 'package:ap_common/widgets/hint_content.dart';
import 'package:ap_common/widgets/progress_dialog.dart';
import 'package:printing/printing.dart';
import 'package:sprintf/sprintf.dart';

enum _State { loading, finish, error, empty }

class TuitionAndFeesPage extends StatefulWidget {
  final String username;
  final String password;

  const TuitionAndFeesPage({Key key, this.username, this.password})
      : super(key: key);

  @override
  _TuitionAndFeesPageState createState() => _TuitionAndFeesPageState();
}

class _TuitionAndFeesPageState extends State<TuitionAndFeesPage> {
  _State state = _State.loading;

  AppLocalizations app;

  List<TuitionAndFees> items;

  GeneralCallback get callback => GeneralCallback(
        onFailure: (DioError e) => setState(() {
          state = _State.error;
          switch (e.type) {
            case DioErrorType.CONNECT_TIMEOUT:
            case DioErrorType.SEND_TIMEOUT:
            case DioErrorType.RECEIVE_TIMEOUT:
            case DioErrorType.RESPONSE:
            case DioErrorType.CANCEL:
              break;
            case DioErrorType.DEFAULT:
              throw e;
              break;
          }
        }),
        onError: (_) => setState(() => state = _State.error),
      );

  @override
  void initState() {
    FA.setCurrentScreen("TuitionAndFeesPage", "tuition_and_fees_page.dart");
    _getData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    app = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(app.tuitionAndFees),
        backgroundColor: ApTheme.of(context).blue,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    switch (state) {
      case _State.loading:
        return Container(
            child: CircularProgressIndicator(), alignment: Alignment.center);
      case _State.error:
      case _State.empty:
        return FlatButton(
          onPressed: _getData,
          child: HintContent(
            icon: Icons.assignment,
            content: state == _State.error
                ? app.clickToRetry
                : app.tuitionAndFeesEmpty,
          ),
        );
      default:
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              state = _State.loading;
            });
            await _getData();
            FA.logAction('refresh', 'swipe');
            return null;
          },
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              if (index == 0)
                return Text(
                  app.tuitionAndFeesPageHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ApTheme.of(context).grey),
                );
              else
                return _notificationItem(items[index - 1]);
            },
            itemCount: items.length + 1,
          ),
        );
    }
  }

  Widget _notificationItem(TuitionAndFees item) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          title: Text(
            item.title,
            style: TextStyle(fontSize: 18.0),
          ),
          trailing: Text(
            '${item.paymentStatus}',
            style: TextStyle(
              fontSize: 16.0,
              color: item.isPayment ? Colors.green : Colors.red,
            ),
          ),
          onTap: () async {
            //if (!item.serialNumber.contains('act=51'))
            showDialog(
              context: context,
              builder: (_) => SimpleDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(16),
                  ),
                ),
                title: Text(app.tuitionAndFeesPageDialogTitle),
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.print),
                    title: Text(app.printing),
                    onTap: () {
                      Navigator.of(context).pop(0);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.share),
                    title: Text(app.share),
                    onTap: () {
                      Navigator.of(context).pop(1);
                    },
                  ),
                ],
              ),
            ).then((index) async {
              if (index != null) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) => WillPopScope(
                      child: ProgressDialog(app.loading),
                      onWillPop: () async {
                        return false;
                      }),
                  barrierDismissible: false,
                );
                List<int> bytes =
                    await Helper.instance.downloadFile(item.serialNumber);
                Navigator.of(context, rootNavigator: true).pop();
                switch (index) {
                  case 0:
                    await Printing.layoutPdf(
                      onLayout: (format) async => bytes,
                      name: item.title,
                    );
                    FA.logAction('export_by_printing', '');
                    break;
                  case 1:
                    await Printing.sharePdf(
                        bytes: bytes, filename: '${item.title}.pdf');
                    FA.logAction('export_by_share', '');
                    break;
                }
              }
            });
          },
          subtitle: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              sprintf(
                app.tuitionAndFeesItemTitleFormat,
                [
                  item.amount,
                  item.dateOfPayment,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Null> _getData() async {
    var response = await Helper.instance.tfLogin(
      username: widget.username,
      password: widget.password,
      callback: callback,
    );
    if (response != null) {
      items = await Helper.instance.getTfData(
        callback: callback,
      );
      if (mounted && items != null)
        setState(() {
          if (items.length == 0)
            state = _State.empty;
          else
            state = _State.finish;
        });
    }
  }
}
