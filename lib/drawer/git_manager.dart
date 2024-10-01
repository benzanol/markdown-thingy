import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/components/global_value_key.dart';
import 'package:notes/components/icon_btn.dart';
import 'package:notes/components/prompts.dart';
import 'package:notes/editor/note_handler.dart';

const _secureStorage = FlutterSecureStorage();
const _githubUsernameField = "github_username";
const _githubRepoField = "github_repo";
const _githubTokenField = "github_token";


class GithubRepo {
  GithubRepo({required this.repo, required this.username, required this.token});
  final String repo;
  final String username;
  final String token;

  String get authLink => 'https://$username:$token@github.com/$username/$repo.git';

  void writeToStorage() {
    _secureStorage.write(key: _githubRepoField, value: repo);
    _secureStorage.write(key: _githubUsernameField, value: username);
    _secureStorage.write(key: _githubTokenField, value: token);
  }
}

Future<GithubRepo?> promptForGithubCredentials(BuildContext context, GithubRepo? existing) async {
  final repoController = TextEditingController(text: existing?.repo);
  final usernameController = TextEditingController(text: existing?.username);
  final tokenController = TextEditingController(text: existing?.token);

  return await showDialog<GithubRepo>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Enter GitHub Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(hintText: 'GitHub Username'),
            ),
            TextField(
              controller: repoController,
              decoration: const InputDecoration(hintText: 'GitHub Repo'),
            ),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(hintText: 'GitHub Token'),
              // obscureText: true,  // Hide the token for security
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (repoController.text.isNotEmpty &&
                usernameController.text.isNotEmpty &&
                tokenController.text.isNotEmpty) {
                Navigator.of(context).pop(
                  GithubRepo(
                    repo: repoController.text,
                    username: usernameController.text,
                    token: tokenController.text,
                  ),
                );
              } else {
                Navigator.of(context).pop(null);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      );
    },
  );
}


class _GitStatusWidget extends StatefulWidget {
  _GitStatusWidget({required this.status}) : super(key: GlobalValueKey(status));
  final GitStatus status;

  @override
  State<_GitStatusWidget> createState() => _GitStatusWidgetState();
}

class _GitStatusWidgetState extends State<_GitStatusWidget> {
  _GitStatusWidgetState();

  void update() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.status.build(context);
}

class GitStatus {
  final NoteHandlerState handler;
  GithubRepo? repo;
  bool gotStorage = false;

  GitStatus({required this.handler}) {
    _secureStorage.readAll().then((storage) {
        gotStorage = true;
        final link = storage[_githubRepoField];
        final username = storage[_githubUsernameField];
        final token = storage[_githubTokenField];
        if (link != null && username != null && token != null) {
          repo = GithubRepo(repo: link, username: username, token: token);
        }
        update();
    });
  }


  Directory get root => handler.repoRoot;

  Widget widget() => _GitStatusWidget(status: this);
  void update() {
    final state = GlobalValueKey(this).currentState;
    if (state is _GitStatusWidgetState) state.update();
  }

  Future<ProcessResult> gitRunOrErr(List<String> args) async {
    print('Git: $args');
    final repo = this.repo;
    if (repo == null) throw 'Repo is not initialized';

    final result = await Process.run(
      'git', args,
      workingDirectory: root.path,
      // environment: {
      //   'GIT_ASKPASS': 'echo',
      //   'GIT_USERNAME': repo.username,
      //   'GIT_PASSWORD': repo.token,
      // },
    );

    if (result.exitCode != 0) throw 'Git Error: $args\n${result.stdout}${result.stderr}';
    return result;
  }

  String gitCommitFormat() {
    final now = DateTime.now();
    return [
      [(now.year, 4), (now.month, 2), (now.day, 2)],
      [(now.hour, 2), (now.minute, 2), (now.second, 2)],
    ].map((s) => s.map((n) => n.$1.toString().padLeft(n.$2, '0')).join('-')).join(' ');
  }

  Future<void> gitSave() async {
    await gitRunOrErr(['add', '-A']);
    final checkChanges = await gitRunOrErr(['status', '--porcelain']);
    if (checkChanges.stdout.toString().isNotEmpty) {
      await gitRunOrErr(['commit', '-m', gitCommitFormat()]);
    }
  }

  Future<(int, int)> gitSaveThenCompare() async {
    await gitSave();
    await gitRunOrErr(['fetch']);
    final result = await gitRunOrErr(['rev-list', '--left-right', 'master...origin/master', '--count']);
    final parts = result.stdout.toString().trim().split(RegExp(r'\s+')).map(int.parse).toList();
    return (parts[0], parts[1]);
  }

  static const _iconScale = 1.4;
  Widget build(BuildContext context) {
    final repo = this.repo;
    Widget configButton = IconBtn(
      icon: MdiIcons.github,
      scale: _iconScale,
      onPressed: () => promptForGithubCredentials(context, repo).then((newRepo) {
          if (newRepo != null) {
            newRepo.writeToStorage();
            this.repo = newRepo;
            update();
          }
      }),
    );

    if (!gotStorage) {
      return const Text('Waiting');
    } else if (repo == null) {
      return configButton;
    } else if (!Directory.fromUri(root.uri.resolve('.git')).existsSync()) {
      // Clone the repo
      final cloneButton = IconBtn(
        icon: MdiIcons.downloadBoxOutline,
        scale: _iconScale,
        onPressed: () async {
          final files = root.listSync();
          if (files.isEmpty || await promptConfirmation(context, 'Delete Existing Files?')) {
            for (final file in files) {
              file.deleteSync(recursive: true);
            }
            await gitRunOrErr(['clone', repo.authLink, '.']);
            update();
          }
        },
      );
      return Row(mainAxisSize: MainAxisSize.min, children: [configButton, cloneButton]);
    }


    (String, List<TextButton>) syncPopup(BuildContext context, AsyncSnapshot<(int, int)> snapshot) {
      void close() => Navigator.of(context).pop();
      gitAndClose(List<String> args) { gitRunOrErr(args); close(); }
      void forcePull() => gitAndClose(['reset', '--hard', 'origin/master']);
      void forcePush() => gitAndClose(['push', '--force', 'origin', 'HEAD:master']);
      void forcePushTemp() => gitAndClose(['push', '--force', 'origin', 'HEAD:local']);

      if (snapshot.connectionState != ConnectionState.done) {
        return ('Loading...', <TextButton>[]);
      } else if (!snapshot.hasData) {
        return (snapshot.error.toString(), <TextButton>[]);
      }

      final (local, remote) = snapshot.data!;
      if (local > 0 && remote > 0) {
        return (
          'Local (+$local) and remote (+$remote) conflict.',
          [
            TextButton(onPressed: forcePushTemp, child: const Text('Push to Temp Branch (Safe)')),
            TextButton(onPressed: forcePull, child: const Text('Use Remote (Force Pull)')),
            TextButton(onPressed: forcePush, child: const Text('Use Local (Force Push)')),
          ],
        );
      } else if (local > 0) {
        return (
          'Local (+$local) is ahead of Remote. Push?',
          [TextButton(onPressed: forcePush, child: const Text('Push'))],
        );
      } else if (remote > 0) {
        return (
          'Remote (+$remote) is ahead of Local. Pull?',
          [TextButton(onPressed: forcePush, child: const Text('Pull'))],
        );
      } else {
        return ('Local and Remote are in sync!', <TextButton>[]);
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        configButton,
        IconBtn(
          icon: Icons.sync,
          scale: _iconScale,
          onPressed: () => showDialog(
            context: context,
            builder: (context) => FutureBuilder(
              future: gitSaveThenCompare(),
              builder: (context, snapshot) {
                final (content, buttons) = syncPopup(context, snapshot);
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: AlertDialog(
                    title: const Text('Sync Repo'),
                    content: Text(content),
                    actions: buttons.map((btn) => Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const RoundedRectangleBorder(),
                            padding: const EdgeInsets.all(15),
                          ),
                          onPressed: btn.onPressed,
                          child: btn.child,
                        ),
                    )).toList(),
                    actionsAlignment: MainAxisAlignment.start,
                    actionsOverflowAlignment: OverflowBarAlignment.start,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
