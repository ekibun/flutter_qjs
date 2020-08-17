/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:51
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-17 21:46:10
 */
import 'package:flutter/material.dart';

import 'package:flutter_qjs_example/test.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({ Key key }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_qjs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(brightness: Brightness.dark, elevation: 0),
        primaryColor: Color(0xfff09199),
        accentColor: Color(0xffec818a),
        backgroundColor: Colors.grey[300],
        primaryColorBrightness: Brightness.dark,
      ),
      routes: {
        'home': (BuildContext context) => TestPage(),
      },
      initialRoute: 'home',
    );
  }

}