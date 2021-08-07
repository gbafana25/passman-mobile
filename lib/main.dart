import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:oauth2_client/github_oauth2_client.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:openpgp/openpgp.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';



String client_id = "";
String client_secret = "";
const String redirect = "passman://redirect";
const String issuer = "https://github.com";
String _username = "";
String _repo_name = "";
String _gpg_passphrase = "";
var users = [];
var _base_site = "";
var converted = "";


var _siteList = <String>[];

bool logged_in = false;

// Profile Data
String name = "";
String email = "";
// placeholder that can be generated without using the api
String avatar_default = "https://github.com/identicons/$_username.png";

OAuth2Client gh = GitHubOAuth2Client(redirectUri: redirect, customUriScheme: "passman");

OAuth2Helper helper = OAuth2Helper(
    gh,
    clientId: client_id,
    clientSecret: client_secret,
    scopes: ['read:user', 'repo']
);

Future<void> _oauth_login() async {
  try {
    http.Response login = await helper.get("https://github.com/login/oauth/authorize?scope=read:user&client_id=${client_id}");
  } catch (e) {
    print("Error $e");
  }
}

Future<void> getUserInfo() async {

  try {
    http.Response response = await helper.get("https://api.github.com/users/$_username");
    //print(response.body);
    var profile_data = json.decode(response.body);
    email = profile_data['email'];
    name = profile_data['name'];
    avatar_default = profile_data['avatar_url'];
    logged_in = true;
  } catch (e) {
    print("Error: ${e}");
  }

}

Future<void> downloadFiles() async {
  try {
    http.Response resp = await helper.get("https://api.github.com/repos/$_username/$_repo_name/contents");

    var data = json.decode(resp.body);
    //print(data);
    for(var i = 0; i < data.length; i++) {
      if(data[i]['type'] == 'dir') {
        http.Response folder = await helper.get(data[i]['url']);
        var link = json.decode(folder.body);
        //print(link[0]['url']);

        for(var j = 0; j < link.length; j++) {
          http.Response file = await helper.get(link[j]['url']);
          var con = json.decode(file.body);
          http.Response raw = await helper.get(con['download_url']);
          var base_dir = await _createPath(data[i]['name']);
          String filename = con['name'];
          File fullpath = await _createFile(base_dir, filename);
          fullpath.writeAsBytes(raw.bodyBytes);

        }

      } else if(data[i]['name'] == 'priv.pgp') {
        http.Response keyfile = await helper.get(data[i]['download_url']);
        var base_dir = await getApplicationDocumentsDirectory();
        File key = await _createFile(base_dir.path, "priv.pgp");
        //File key = File("${base_dir.path}/priv.pgp");
        //print(keyfile.body);
        key.writeAsString(keyfile.body);

      }
    }

  } catch (e) {
    print("Error: ${e}");
  }
}

Future<String> _getPrivateKey() async {
  final base = await getApplicationDocumentsDirectory();
  var dir = "${base.path}/priv.pgp";
  var file = File(dir);
  return file.readAsString();
}

Future<void> _decryptFile(String src_path) async {
  final base = await getApplicationDocumentsDirectory();
  var path = "${base.path}/${src_path}.enc";
  var priv_key = await _getPrivateKey();
  var src_file = await _readData(path);
  var decoded = Uint8List.fromList(src_file);
  var output;

  try {
    output = await OpenPGP.decryptBytes(decoded, priv_key, _gpg_passphrase);
    //print(output);
  } catch (e) {
    print("Error: ${e}");
  }

  converted = "";
  for(var i = 0; i < output.length; i++) {
    converted += String.fromCharCode(output[i]);
  }
  //print(converted);


}

Future<String> _createPath(String subfolder) async {
  final directory = await getApplicationDocumentsDirectory();
  var full = Directory(directory.path + "/" + subfolder);
  if(await full.exists() == false) {
    await full.create(recursive: true);
  }
  return full.path;

}

Future<File> _createFile(String base_path, String name) async {
  return File("$base_path/$name");
}

Future<Uint8List> _readData(String path) async {
  final file = File(path);
  final data = file.readAsBytes();
  return data;
}

Future<void> _getSites() async {
  try {
    if(_siteList.isEmpty) {
      http.Response resp = await helper.get("https://api.github.com/repos/$_username/$_repo_name/contents");
      var raw = json.decode(resp.body);
      for(var i = 0; i < raw.length; i++) {
        if(raw[i]['type'] == 'dir') {
          _siteList.add(raw[i]['name']);
        }
      }
    }

  } catch (e) {
    print("Error ${e}");
  }
}

Future<List> _listFiles(String site) async {
  final base = await getApplicationDocumentsDirectory();
  var d = "${base.path}/$site";
  Directory full = Directory(d);
  var user_list = <String>[];
  await for(var file in full.list(recursive: true, followLinks: false)) {
    user_list.add(file.path);

  }
  return user_list;
}

Future<void> _parseFileList(String site) async {
  users.clear();
  List files = await _listFiles(site);
  final base = await getApplicationDocumentsDirectory();
  var site_len = site.length + 2;
  for(var i = 0; i < files.length; i++) {
    users.add(files[i].substring(base.path.length + site_len, files[i].length - 4));
  }

}

Future<void> _copyToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}

Future<void> _savePreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('id', client_id);
  await prefs.setString('secret', client_secret);
  await prefs.setString('repo', _repo_name);
  await prefs.setString('username', _username);
  await prefs.setString('password', _gpg_passphrase);
}

Future<void> _getPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  client_id = await prefs.getString('id') ?? "";
  client_secret = await prefs.getString('secret') ?? "";
  _repo_name = await prefs.getString('repo') ?? "";
  _username = await prefs.getString('username') ?? "";
  _gpg_passphrase = await prefs.getString('password') ?? "";
}

void main() {

  runApp(Manager());
  _getPreferences();

}


class Manager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      home: ManagerHome(),
    );
  }
}

class ManagerHome extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _ManagerState();
  }
}

class _ManagerState extends State<ManagerHome> {

  @override
  Widget build(BuildContext build) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Passman"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white54,
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
                decoration: BoxDecoration(
                    color: Colors.black,
                ),
                child: Text("Passman",
                  style: TextStyle(
                      color: Colors.white
                ),
              )
            ),

            ListTile(
              title: Text("Saved Logins"),
              onTap: () {
                Navigator.pop(context);
                _getSites();
                Navigator.push(context, MaterialPageRoute(builder: (context) => CredentialList()));

              }
            ),

            ListTile(
              title: Text("Account"),
              onTap: () {
                Navigator.pop(context);
                if(logged_in == false) {
                  getUserInfo();
                }
                Navigator.push(context, MaterialPageRoute(builder: (context) => AccountPage()));
              }
            ),

            ListTile(
              title: Text("Config"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
              }
            )
          ],
      )
    ),
    );
  }

}

class AccountPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AccountPageState();
  }
}

class SettingsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _SettingsPageState();
  }
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white54,
      ),

      body: Container(
        padding: EdgeInsets.all(30),
        child: ListView(
          children: [
            Container(
              width: 60,
              padding: EdgeInsets.all(10),
              child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Repository',
                    hintText: 'Repository',
                  ),
                  onChanged: (String? value) {
                    _repo_name = value ?? "";
                    _savePreferences();
                  },
                  validator: (String? value) {
                    return (value != null) ? "Repository name can't be empty" : null;
                  }
              ),
            ),

            Container(
              width: 60,
              padding: EdgeInsets.all(10),
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Username',
                ),
                onChanged: (String? value) {
                  _username = value ?? "";
                  _savePreferences();
                },
                validator: (String? value) {
                  return (value != null) ? "Username can't be empty" : null;
                },
              ),
            ),

            Container(
              width: 60,
              padding: EdgeInsets.all(10),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'GPG password',
                  hintText: 'Password',
                ),
                onChanged: (String? value) {
                  _gpg_passphrase = value ?? "";
                  _savePreferences();
                },
                validator: (String? value) {
                  return (value != null) ? "GPG password can't be empty" : null;
                }
              )
            ),

            Container(
              width: 60,
              padding: EdgeInsets.all(10),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Client ID',
                ),
                onChanged: (String? value) {
                  client_id = value ?? "";
                  _savePreferences();
                },
                validator: (String? value) {
                  return (value != null) ? "Client ID can't be empty" : null;
                }
              )
            ),

            Container(
                width: 60,
                padding: EdgeInsets.all(10),
                child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Client Secret',
                    ),
                    onChanged: (String? value) {
                      client_secret = value ?? "";
                      _savePreferences();
                    },
                    validator: (String? value) {
                      return (value != null) ? "Client Secret can't be empty" : null;
                    }
                )
            ),

            Container(
              child: TextButton(
                onPressed: () {
                  _oauth_login();
                },
                child: Text("Login"),
              )
            )


          ],
        )
      )
    );
  }
}

class _AccountPageState extends State<AccountPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Account"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white54,
      ),

      body: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(top: 200),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(bottom: 40),
              child: Image.network(
                avatar_default,
                width: 150,
                height: 150,
              ),
            ),

            Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                )
            ),
            Text(
                email,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                )
            ),

            TextButton(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.black),
                backgroundColor: MaterialStateProperty.all<Color>(Colors.white54),
              ),
              onPressed: () {
                downloadFiles();
              },
              child: Text("Refresh repo"),
            ),

          ],
        )
      ),

    );
  }
}

class CredentialList extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Passman"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white54,
      ),

      body: ListView(
        children: _siteList
            .map((site) => SizedBox(
            height: 60,
            //width: 200,
            child: TextButton(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.black),
                backgroundColor: MaterialStateProperty.all<Color>(Colors.white54),
              ),
              onPressed: () {
                _base_site = site;
                _parseFileList(site);
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => Users()));
              },
              child: Text(site),
            )
          )

          ).toList(),
        ),
      );
  }
}

class Users extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text("Site accounts"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white54,
      ),

      body: ListView(
        children: users
            .map((user) => SizedBox(
                height: 60,
                child: TextButton(
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.all<Color>(Colors.black),
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.white54),
                  ),
                  onPressed: () {
                    _decryptFile("${_base_site}/${user}");
                    _copyToClipboard(converted);
                    final snackBar = SnackBar(content: Text("Copied to clipboard"));
                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  },

                  child: Text(user),
                )
            )
        ).toList()
      )
    );
  }
}