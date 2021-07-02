import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webrtc_myself/ServerUtils.dart';
import 'package:webrtc_myself/call_page.dart';

//@dart =2.9
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  TextEditingController textEditingController = new TextEditingController();
  late WebSocketChannel _channel;
  late String _status;
  late SocketUtils _socketUtils;
  late List<String> _messages;

  @override
  void initState() {
    _status = "";
    _socketUtils = new SocketUtils();
    super.initState();
  }

  void connectionListener(bool connected) {
    setState(() {
      _status = "Status : " + (connected ? ':-)' : ':-( ');
    });
  }

  void messageListener(String message) {
    setState(() {
      _messages.add(message);
    });
    print(_messages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              child: TextFormField(controller: textEditingController),
              width: 400,
              height: 60.0,
            ),
            Container(
              child: FlatButton(
                onPressed: () {
                  _socketUtils.sendMessage(textEditingController.text,
                      connectionListener, messageListener);
                },
                child: Text("Click Me!"),
                color: Colors.redAccent,
              ),
            ),
            SizedBox(
              height: 20.0,
            ),
            Text(_status),
            Container(
              child: FlatButton(
                onPressed: () => Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (c) => CallPage())),
                child: Text("Call Page"),
              ),
            )
          ],
        ),
      ),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
