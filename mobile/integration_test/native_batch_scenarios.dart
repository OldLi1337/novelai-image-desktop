// Production mobile controllers/native storage/plugins and actual HTTP only.
// Synthetic loopback image provider; no paid provider or mock channel.
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:novelai_mobile/batch/batch_redraw_models.dart';
import 'package:novelai_mobile/models/nai_models.dart';
import 'package:novelai_mobile/screens/tools_screen.dart';
import 'package:novelai_mobile/services/background_queue_service.dart';
import 'package:novelai_mobile/services/storage.dart';
import 'native_scenario_support.dart';

final suite = NativeScenarios(4);
Future<void> main() => suite.run(_run);
Future<T> bounded<T>(Future<T> future) =>
    future.timeout(const Duration(seconds: 45));

Future<void> _run() async {
  final c = await NativeContext.create('batch4'),
      app = c.app,
      source = File('${c.root.path}/source.png');
  await source.writeAsBytes(png(64, 64));
  final sourceHash = digest(await source.readAsBytes()),
      wires = <Map<String, dynamic>>[],
      errors = <Object>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var imageStatus = 200, cancelledSocketExpected = false;
  Completer<void>? entered, gate;
  server.listen((r) async {
    var held = false;
    try {
      require(
          r.connectionInfo!.remoteAddress.isLoopback, 'Public fixture access');
      require(r.headers.value('authorization') == 'Bearer $syntheticToken',
          'Non-synthetic credential');
      final raw = await utf8.decoder.bind(r).join();
      if (r.uri.path.endsWith('/user/data')) {
        r.response.headers.contentType = ContentType.json;
        r.response.write(
            '{"subscription":{"tier":3,"active":true,"trainingStepsLeft":{"fixedTrainingStepsLeft":100000,"purchasedTrainingSteps":0}}}');
      } else if (r.uri.path.endsWith('/request-price')) {
        r.response.headers.contentType = ContentType.json;
        r.response.write('{"price":20}');
      } else if (r.uri.path.endsWith('/generate-image') ||
          r.uri.path.endsWith('/augment-image')) {
        final body = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        wires.add({'path': r.uri.path, 'body': body});
        if (entered != null && !entered.isCompleted) {
          held = true;
          entered.complete();
          await gate!.future;
        }
        r.response.statusCode = imageStatus;
        if (imageStatus == 200) {
          final image = png(64, 64, 190);
          r.response.headers.contentType = ContentType('application', 'zip');
          r.response.add(ZipEncoder().encode(
              Archive()..addFile(ArchiveFile('0.png', image.length, image))));
        } else {
          r.response.write('Synthetic image failure');
        }
      } else {
        throw StateError('Unexpected native fixture endpoint ${r.uri.path}');
      }
      await r.response.close();
    } catch (error) {
      if (!(held &&
          cancelledSocketExpected &&
          (error is HttpException || error is SocketException))) {
        errors.add(error);
        print('FEATURE_FIXTURE_ERROR:$error');
      }
    }
  });
  final base = 'http://127.0.0.1:${server.port}';
  app.settings
    ..apiBaseUrl = base
    ..imageBaseUrl = base;
  await c.storage.setSettings(app.settings);
  await c.storage.setToken(syntheticToken);
  final controller = app.batchRedraw;
  await controller.load();
  Future<void> project(String label) async {
    controller.project = BatchRedrawProject.empty(app.params)
      ..sizeMode = 'custom'
      ..globalStrength = .4
      ..candidateCount = 1
      ..globalParams.width = 64
      ..globalParams.height = 64
      ..items = [
        for (var i = 0; i < 2; i++)
          BatchRedrawItem(
              id: '$label-$i',
              name: '$label-$i.png',
              base64: base64Encode(await source.readAsBytes()),
              sourcePath: source.path,
              width: 64,
              height: 64,
              prompt: '$label scene $i')
      ];
    await controller.flush();
  }

  int generated() => wires
      .where((w) => w['path'].toString().endsWith('/generate-image'))
      .length;
  try {
    await project('ordered');
    entered = Completer<void>();
    gate = Completer<void>();
    final before = generated(),
        first = controller.startQueue(controller.project.items);
    await bounded(entered.future);
    require(controller.queueRunning && app.busy,
        'Batch did not acquire shared queue owner');
    if (BackgroundQueueService.supportsBackgroundExecution)
      require(await FlutterForegroundTask.isRunningService,
          'Real Android foreground owner absent');
    await controller.startQueue(controller.project.items);
    require(generated() == before + 1, 'Duplicate start created another queue');
    gate.complete();
    await bounded(first);
    entered = null;
    gate = null;
    final ordered = wires
        .where((w) => w['path'].toString().endsWith('/generate-image'))
        .skip(before)
        .map((w) => w['body']['input'])
        .toList();
    require(
        ordered.length == 2 &&
            ordered[0].contains('ordered scene 0') &&
            ordered[1].contains('ordered scene 1') &&
            !controller.queueRunning &&
            !app.busy &&
            controller.runPhase == 'completed',
        'Batch order/lifecycle mismatch');
    if (BackgroundQueueService.supportsBackgroundExecution)
      require(!await FlutterForegroundTask.isRunningService,
          'Native service owner leaked after batch');
    suite.check('batch', 'queue-order-owner-lifecycle', {
      'actualControllerTwoRequestsInOrder': true,
      'sharedBusyOwnerAndDuplicateStartGuard': true,
      'androidNativeServiceStartStop': Platform.isAndroid,
      'iosForegroundQueueNoBackgroundClaim': Platform.isIOS
    });
    final completed =
        controller.project.items.expand((v) => v.candidates).toList();
    require(
        completed.length == 2 &&
            completed
                .every((v) => app.history.any((h) => h.id == v.historyItemId)),
        'Batch output/history relation missing');
    for (final output in completed) {
      require(
          await File(output.outputPath).exists() &&
              digest(await File(output.outputPath).readAsBytes()) ==
                  digest(png(64, 64, 190)),
          'Batch saved bytes differ');
    }
    final reopened = await Storage().getBatchRedrawProject(app.params);
    require(
        reopened.items.every((v) => v.candidates.length == 1) &&
            (await c.storage.getBatchRun())?['phase'] == 'completed',
        'Batch completion not durable');
    suite.check('batch', 'history-output', {
      'actualNativeFiles': 2,
      'literalOutputHash': digest(png(64, 64, 190)),
      'historyIdsLinked': true,
      'projectAndRunReopened': true
    });
    await project('retry');
    imageStatus = 400;
    final oldHistory = app.history.length;
    await bounded(controller.startQueue(controller.project.items));
    require(
        controller.runPhase == 'failed' &&
            controller.project.items.first.status == BatchItemStatus.failed &&
            app.history.length == oldHistory,
        'Batch HTTP error lost prior state');
    imageStatus = 200;
    await bounded(controller.startQueue([controller.project.items.first]));
    require(controller.project.items.first.candidates.length == 1,
        'Explicit retry did not save image');
    entered = Completer<void>();
    gate = Completer<void>();
    final historyAtCancel = app.history.length,
        postsAtCancel = generated(),
        stopped = controller.startQueue([controller.project.items.last]);
    await bounded(entered.future);
    cancelledSocketExpected = true;
    controller.cancelQueue();
    await bounded(stopped);
    gate.complete();
    entered = null;
    gate = null;
    require(
        controller.runPhase == 'cancelled' &&
            !app.busy &&
            !controller.queueRunning &&
            app.history.length == historyAtCancel &&
            generated() == postsAtCancel + 1 &&
            digest(await source.readAsBytes()) == sourceHash,
        'Batch cancellation created output/continued queue/lost source');
    suite.check('batch', 'cancel-errors-retry', {
      'upstream400PreservesHistory': true,
      'explicitRetryOneSavedOutput': true,
      'realHeldHttpCancelledBeforeResponseRelease': true,
      'sourceHashPreserved': true,
      'noExtraQueueSubmission': true
    });

    // Actual director cancellation affordance and scoped transport, plus invalid
    // input/upstream errors; existing generation24 proves its other two scenarios.
    app.workbenchImage =
        WorkingImage(filePath: source.path, width: 64, height: 64);
    app.directorTool = 'colorize';
    app.augmentOptions.colorizePrompt = 'synthetic blue';
    final oldOutputs = app.history.length, beforeInvalid = wires.length;
    app.workbenchImage = null;
    await app.augment();
    require(wires.length == beforeInvalid && app.history.length == oldOutputs,
        'Missing director input submitted');
    app.workbenchImage =
        WorkingImage(filePath: source.path, width: 64, height: 64);
    imageStatus = 400;
    await bounded(app.augment());
    require(app.history.length == oldOutputs && !app.busy,
        'Director upstream failure created output');
    imageStatus = 200;
    await mount(app, const ToolsScreen(kind: ToolPageKind.postprocess));
    final switcher = elements((w) => w is SegmentedButton<String>).single.widget
        as SegmentedButton<String>;
    switcher.onSelectionChanged!({'director'});
    await frame();
    entered = Completer<void>();
    gate = Completer<void>();
    final director = app.augment();
    await bounded(entered.future);
    await frame();
    FilledButton? stopButton;
    for (final icon in elements((w) => w is Icon && w.icon == Icons.stop)) {
      icon.visitAncestorElements((e) {
        if (e.widget is FilledButton) {
          stopButton = e.widget as FilledButton;
          return false;
        }
        return true;
      });
    }
    require(
        stopButton?.onPressed != null, 'Native director stop button missing');
    stopButton!.onPressed!();
    await bounded(director);
    gate.complete();
    entered = null;
    gate = null;
    require(
        !app.busy &&
            !app.postprocessRunning &&
            app.history.length == oldOutputs &&
            digest(await source.readAsBytes()) == sourceHash,
        'Director cancel did not preserve source/history');
    suite.check('postprocess', 'invalid-cancel-errors', {
      'invalidInputNoSubmit': true,
      'upstream400NoOutput': true,
      'actualNativeStopButton': true,
      'heldHttpCancelledBeforeRelease': true,
      'sourceAndHistoryPreserved': true
    });
    require(errors.isEmpty, 'Fixture transport error');
  } finally {
    if (gate != null && !gate.isCompleted) gate.complete();
    await server.close(force: true);
    await mount(app, const Scaffold(body: Text('Batch/director complete')));
    await c.close();
  }
}
