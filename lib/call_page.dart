import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:random_string/random_string.dart';
import 'package:webrtc_myself/websocket.dart';

class CallPage extends StatefulWidget {
  const CallPage({Key? key}) : super(key: key);

  @override
  _CallPageState createState() => _CallPageState();
}

class Session {
  Session({required this.sid, required this.pid});
  String sid;
  String pid;
  late RTCPeerConnection pc;
  late RTCDataChannel dc;
  late RTCVideoRenderer _selfRenderer;
  late TextEditingController fieldController;
  List<RTCIceCandidate> remoteCandidates = [];
}

class _CallPageState extends State<CallPage> {
  //MediaStream _localStream ;
  RTCVideoRenderer _selfRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _guestRenderer = new RTCVideoRenderer();
  JsonDecoder _decoder = JsonDecoder();
  // RTCPeerConnection _peerConnection;
  // MediaStream _localStream;
  TextEditingController _fieldController = new TextEditingController();
  TextEditingController _selfID = new TextEditingController();
  bool useScreen = false;
  late MediaStream _localStream;
  late SimpleWebSocket _webSocket = SimpleWebSocket("");
  JsonEncoder _encoder = new JsonEncoder();
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  String _selfId = randomNumeric(6);
  Map<String, Session> _session = {};

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      /*
       * turn server configuration example.
      {
        'url': 'turn:123.45.67.89:3478',
        'username': 'change_to_real_user',
        'credential': 'change_to_real_secret'
      },
      */
    ]
  };

  Future<MediaStream> createStream(String media, bool userScreen) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    MediaStream stream = userScreen
        ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
        : await navigator.mediaDevices.getUserMedia(mediaConstraints);

    _selfRenderer.srcObject = stream;
    return stream;
  }

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };
  // createStream(String mediaStream, bool screenSharing) {}

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _selfID.text = _selfId;
    _selfRenderer.initialize();
    _guestRenderer.initialize();
  }

  invite(
    String peerId,
    String media,
    useScreen,
  ) async {
    var sessionId = _selfId + '-' + peerId;
    Session session = await _createSession(
      sessionId: sessionId,
      peerId: peerId,
      media: media,
      screenSharing: useScreen,
    );
    _session[sessionId] = session;
    print("This is sessionId" + sessionId.toString());
    _createOffer(
      session,
      media,
    );
  }

  Future<void> _createOffer(Session session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc.createOffer({'offerToReceiveVideo ': 1});
      print(s.toString());
      // var sddp = parse(s.sdp);//   <-----------Generting sdp for debugging readability.
      // print(jsonEncode(session));
      await session.pc.setLocalDescription(s);
      // _send('offer', {
      //   'to' : session.pid,
      //   'from' : _selfId,
      //   'description' : {'sdp' :s.sdp, 'type' : s.type},
      //   'session_id' : session.sid,
      //   'media' : media,
      // });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<Session> _createSession(
      {required String sessionId,
      required String peerId,
      required String media,
      required bool screenSharing}) async {
    var newSession = Session(sid: sessionId, pid: peerId);
    _localStream = await createStream(
      media,
      screenSharing,
    );
    print(_iceServers);
    RTCPeerConnection pc = await createPeerConnection({
      ..._iceServers,
    }, _config);

    pc.addStream(_localStream);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(e.candidate.toString() +
            e.sdpMid.toString() +
            e.sdpMlineIndex.toString());
        print("This is selfId" + _selfId);
        print("This is peerId" + peerId);
      }
      _send('candidate', {
        'to': peerId,
        'from': _selfId,
        'candidate': {
          'sdpMLineIndex': e.sdpMlineIndex,
          'sdpMid': e.sdpMid,
          'candidate': e.candidate,
        },
        'session_id': sessionId,
      });
    };
    // print("This is Session Id" + sessionId);
    newSession.pc = pc;
    return newSession;
  }

  _send(event, data) {
    var request = Map();
    request["type"] = event;
    request["data"] = data;
    _webSocket.send(_encoder.convert(request));
    print("This is the request form user -> " + (_encoder.convert(request)));
  }

  Future<void> _reply(String media, var value) async {
    var message = await _decoder.convert(value);
    print("This is dynamic message->> " + message.toString());
    Map<String, dynamic> mapData = message;
    var data = mapData["data"];
    try {
      var peerId = data['from'];
      var description = data['description'];
      var media = data = data["media"];
      var sessionId = data['session_id'];
      var session = _session[sessionId];
      var newSession = await _createSession(
          sessionId: sessionId,
          peerId: peerId,
          media: media,
          screenSharing: false);
      _session[sessionId] = newSession;
      await newSession.pc.setRemoteDescription(
          RTCSessionDescription(description["sdp"], description["type"]));
      _createAnswer(newSession, media);
      if (newSession.remoteCandidates.length > 0) {
        newSession.remoteCandidates.forEach((candidate) async {
          await newSession.pc.addCandidate(candidate);
        });
        newSession.remoteCandidates.clear();
      }
    } catch (e) {}
  }

  Future<void> _createAnswer(Session session, String media) async {
    try {
      RTCSessionDescription s =
          await session.pc.createAnswer(media == "media" ? _dcConstraints : {});
      await session.pc.setRemoteDescription(s);
      // _send('answer', {
      //   'to': session.pid,
      //   'from': _selfId,
      //   'description': {'sdp': s.sdp, 'type': s.type},
      //   'session_id': session.sid,
      // });
    } catch (e) {}
  }

  _invitePeer(
      BuildContext context, String peerId, RTCVideoRenderer selfRenderer) {
    print("Connect button is clicked");
    if (peerId != _selfId) {
      invite(peerId, 'video', useScreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Call Page"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                    child: Padding(
                  padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                  child: Container(
                      height: 250,
                      width: 200,
                      child: new RTCVideoView(
                        _selfRenderer,
                        mirror: true,
                      )),
                )),
                Flexible(
                  child: Container(
                    child: new RTCVideoView(
                      _guestRenderer,
                      mirror: true,
                    ),
                    height: 250.0,
                    width: MediaQuery.of(context).size.width / 2,
                  ),
                )
              ],
            ),
            Column(
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 50),
                      child: Text("Self Id"),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 180),
                      child: Text("Guest Id"),
                    )
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                Row(
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: Container(
                          height: 50,
                          width: 100,
                          child: TextFormField(
                            controller: _selfID,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              //hintText: "Self ID",
                            ),
                          ),
                        )),
                    Padding(
                        padding: const EdgeInsets.only(left: 120),
                        child: Container(
                          height: 50,
                          width: 100,
                          child: TextFormField(
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              //hintText: "Guest ID",
                            ),
                          ),
                        ))
                  ],
                ),
                Row(
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(left: 40.0),
                        child: MaterialButton(
                          child: Text(
                            "Invite",
                            style: TextStyle(color: Colors.amber[100]),
                          ),
                          onPressed: () =>
                              {_invitePeer(context, "", _selfRenderer)},
                          color: Colors.red[300],
                        )),
                    Padding(
                        padding: const EdgeInsets.only(left: 130.0),
                        child: MaterialButton(
                          child: Text("Answer",
                              style: TextStyle(color: Colors.amber[100])),
                          onPressed: () =>
                              _reply("media", _fieldController.text),
                          color: Colors.red[300],
                        )),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(left: 20.0, right: 20.0, bottom: 0),
                  child: Container(
                    height: 200,
                    width: 400,
                    child: TextField(
                      controller: _fieldController,
                      keyboardType: TextInputType.multiline,
                      maxLines: 4,
                      maxLength: TextField.noMaxLength,
                    ),
                  ),
                ),
                MaterialButton(
                  child: Text("Connect",
                      style: TextStyle(color: Colors.amber[100])),
                  onPressed: null,
                  disabledColor: Colors.green[300],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
