// File: test/doctor_call_test.dart
// Comprehensive Test Suite for Milestone 4: Telehealth Voice & Video Calling (R4)
import 'dart:async';

import 'package:do_an_cntt_11/core/call/call_models.dart';
import 'package:do_an_cntt_11/core/call/call_signaling_service.dart';

void main() async {
  print('======================================================================');
  print('Running Milestone 4 Telehealth Calling Comprehensive Test Suite (R4)');
  print('======================================================================');

  int totalSpecs = 0;
  int passedSpecs = 0;

  void expect(String spec, bool condition, [String detail = '']) {
    totalSpecs++;
    if (condition) {
      passedSpecs++;
      print('  [PASS] Spec $totalSpecs: $spec');
    } else {
      print('  [FAIL] Spec $totalSpecs: $spec -> $detail');
      throw AssertionError('FAILED Spec $totalSpecs: $spec -> $detail');
    }
  }

  final service = CallSignalingService.instance;

  // ===========================================================================
  // GROUP 1: CallState Enum & CallSessionModel Data Model Serialization
  // ===========================================================================
  print('\nGroup 1: CallState Enum & CallSessionModel Serialization');

  expect('CallState enum contains 9 distinct lifecycle states',
    CallState.values.length == 9 &&
    CallState.values.contains(CallState.idle) &&
    CallState.values.contains(CallState.dialing) &&
    CallState.values.contains(CallState.ringing) &&
    CallState.values.contains(CallState.connected) &&
    CallState.values.contains(CallState.ended) &&
    CallState.values.contains(CallState.rejected) &&
    CallState.values.contains(CallState.busy) &&
    CallState.values.contains(CallState.missed) &&
    CallState.values.contains(CallState.failed),
  );

  final defaultSession = CallSessionModel(
    callId: 'call_test_01',
    callerId: 'patient_01',
    callerName: 'Nguyễn Văn A (Bệnh nhân)',
    calleeId: 'doctor_01',
    calleeName: 'BS. Chuyên Khoa Tuấn',
    callType: 'audio',
  );

  expect('Default CallSessionModel initializes with status dialing',
    defaultSession.status == CallState.dialing);
  expect('Default CallSessionModel initializes with isMuted = false',
    defaultSession.isMuted == false);
  expect('Default CallSessionModel initializes with isCameraEnabled = true',
    defaultSession.isCameraEnabled == true);
  expect('Default CallSessionModel initializes with isUsingFrontCamera = true',
    defaultSession.isUsingFrontCamera == true);
  expect('Default CallSessionModel initializes with durationSeconds = 0',
    defaultSession.durationSeconds == 0);
  expect('Default CallSessionModel initializes with areMediaTracksDisposed = false',
    defaultSession.areMediaTracksDisposed == false);
  expect('Default CallSessionModel initializes with failureReason = null',
    defaultSession.failureReason == null);

  // ===========================================================================
  // GROUP 2: Duration Formatting (MM:SS and HH:MM:SS)
  // ===========================================================================
  print('\nGroup 2: Formatted Duration Computation');

  defaultSession.durationSeconds = 0;
  expect('formattedDuration formats 0s as 00:00', defaultSession.formattedDuration == '00:00');

  defaultSession.durationSeconds = 45;
  expect('formattedDuration formats 45s as 00:45', defaultSession.formattedDuration == '00:45');

  defaultSession.durationSeconds = 300;
  expect('formattedDuration formats 300s (5m) as 05:00', defaultSession.formattedDuration == '05:00');

  defaultSession.durationSeconds = 3665;
  expect('formattedDuration formats 3665s as 01:01:05', defaultSession.formattedDuration == '01:01:05');

  // ===========================================================================
  // GROUP 3: Model Serialization toMap & fromMap Roundtrip
  // ===========================================================================
  print('\nGroup 3: Serialization toMap & fromMap');

  final complexSession = CallSessionModel(
    callId: 'call_ser_02',
    callerId: 'pat_99',
    callerName: 'Trần Thị Mai',
    calleeId: 'doc_88',
    calleeName: 'BS. Hoàng Yến',
    callType: 'video',
    status: CallState.connected,
    isMuted: true,
    isCameraEnabled: false,
    isUsingFrontCamera: false,
    durationSeconds: 125,
    areMediaTracksDisposed: false,
    failureReason: null,
  );

  final map = complexSession.toMap();
  expect('toMap serializes call_id correctly', map['call_id'] == 'call_ser_02');
  expect('toMap serializes caller_id correctly', map['caller_id'] == 'pat_99');
  expect('toMap serializes call_type as video', map['call_type'] == 'video');
  expect('toMap serializes status as connected', map['status'] == 'connected');
  expect('toMap serializes is_muted as true', map['is_muted'] == true);
  expect('toMap serializes is_camera_enabled as false', map['is_camera_enabled'] == false);
  expect('toMap serializes is_using_front_camera as false', map['is_using_front_camera'] == false);
  expect('toMap serializes duration_seconds as 125', map['duration_seconds'] == 125);

  final restored = CallSessionModel.fromMap(map);
  expect('fromMap restores callId', restored.callId == complexSession.callId);
  expect('fromMap restores callerName', restored.callerName == complexSession.callerName);
  expect('fromMap restores callType', restored.callType == complexSession.callType);
  expect('fromMap restores status connected', restored.status == CallState.connected);
  expect('fromMap restores isMuted', restored.isMuted == true);
  expect('fromMap restores isCameraEnabled', restored.isCameraEnabled == false);
  expect('fromMap restores isUsingFrontCamera', restored.isUsingFrontCamera == false);
  expect('fromMap restores durationSeconds', restored.durationSeconds == 125);

  // Test camelCase fallback compatibility
  final camelMap = {
    'callId': 'call_camel_03',
    'callerId': 'pat_camel',
    'callerName': 'Lê Hữu',
    'calleeId': 'doc_camel',
    'calleeName': 'BS. Nam',
    'callType': 'audio',
    'status': 'ringing',
    'isMuted': false,
    'isCameraEnabled': true,
    'durationSeconds': 10,
  };
  final camelRestored = CallSessionModel.fromMap(camelMap);
  expect('fromMap supports camelCase keys fallback',
    camelRestored.callId == 'call_camel_03' && camelRestored.status == CallState.ringing);

  // Test copyWith
  final updated = complexSession.copyWith(
    status: CallState.ended,
    areMediaTracksDisposed: true,
    durationSeconds: 300,
  );
  expect('copyWith preserves original fields', updated.callId == complexSession.callId);
  expect('copyWith updates status to ended', updated.status == CallState.ended);
  expect('copyWith updates areMediaTracksDisposed to true', updated.areMediaTracksDisposed == true);
  expect('copyWith updates durationSeconds to 300', updated.durationSeconds == 300);

  // ===========================================================================
  // GROUP 4: CallSignalingService Call Lifecycle (Start -> Ringing -> Connected -> End)
  // ===========================================================================
  print('\nGroup 4: CallSignalingService Audio & Video Lifecycle');
  service.reset();
  expect('service.reset clears activeSession and callHistory',
    service.activeSession == null && service.callHistory.isEmpty);

  // Step 1: Start Audio Call
  final audioCall = await service.startCall(
    callerId: 'pat_01',
    callerName: 'Bệnh nhân',
    calleeId: 'doc_01',
    calleeName: 'BS. Tuấn',
    callType: 'audio',
  );
  expect('startCall transitions session to ringing', audioCall.status == CallState.ringing);
  expect('startCall assigns activeSession to service', service.activeSession?.callId == audioCall.callId);

  // Step 2: Accept Call
  service.acceptCall(audioCall.callId);
  expect('acceptCall transitions status to connected', audioCall.status == CallState.connected);

  // Step 3: Advance duration
  service.advanceCallDuration(45);
  expect('advanceCallDuration increments session durationSeconds to 45', audioCall.durationSeconds == 45);
  expect('formattedDuration displays 00:45', audioCall.formattedDuration == '00:45');

  // Step 4: Toggle Mic
  service.toggleMic();
  expect('toggleMic mutes session', audioCall.isMuted == true);
  service.toggleMic();
  expect('toggleMic unmutes session', audioCall.isMuted == false);

  // Step 5: End Call
  service.endCall(audioCall.callId);
  expect('endCall transitions status to ended', audioCall.status == CallState.ended);
  expect('endCall disposes media tracks', audioCall.areMediaTracksDisposed == true);
  expect('endCall archives session to callHistory', service.callHistory.length == 1);
  expect('callHistory contains ended callId', service.callHistory.first.callId == audioCall.callId);

  // Idempotency check: duplicate endCall does not duplicate in callHistory
  service.endCall(audioCall.callId);
  expect('endCall is idempotent and does not duplicate history entries', service.callHistory.length == 1);

  // ===========================================================================
  // GROUP 5: Video Call Features (Camera toggle & Flip camera)
  // ===========================================================================
  print('\nGroup 5: Video Call Features');
  service.reset();

  final videoCall = await service.startCall(
    callerId: 'pat_02',
    callerName: 'Bệnh nhân Video',
    calleeId: 'doc_02',
    calleeName: 'BS. Chuyên Khoa',
    callType: 'video',
  );
  expect('videoCall starts in ringing state', videoCall.status == CallState.ringing);
  expect('videoCall callType is video', videoCall.callType == 'video');

  service.acceptCall(videoCall.callId);
  expect('videoCall accepted to connected', videoCall.status == CallState.connected);

  // Flip camera test
  expect('Default camera is front', videoCall.isUsingFrontCamera == true);
  service.flipCamera();
  expect('flipCamera switches to back camera', videoCall.isUsingFrontCamera == false);
  service.flipCamera();
  expect('flipCamera switches back to front camera', videoCall.isUsingFrontCamera == true);

  // Toggle camera test
  expect('Default camera is enabled', videoCall.isCameraEnabled == true);
  service.toggleCamera();
  expect('toggleCamera disables video feed', videoCall.isCameraEnabled == false);
  service.toggleCamera();
  expect('toggleCamera re-enables video feed', videoCall.isCameraEnabled == true);

  service.endCall(videoCall.callId);
  expect('videoCall ended cleanly with disposed media tracks',
    videoCall.status == CallState.ended && videoCall.areMediaTracksDisposed == true);

  // ===========================================================================
  // GROUP 6: Reject Call & Cancel Dialing
  // ===========================================================================
  print('\nGroup 6: Reject Call & Cancel Dialing');
  service.reset();

  // Test Reject
  final callToReject = await service.startCall(
    callerId: 'pat_03',
    callerName: 'Bệnh nhân 3',
    calleeId: 'doc_03',
    calleeName: 'BS. Lê',
    callType: 'audio',
  );
  service.rejectCall(callToReject.callId);
  expect('rejectCall transitions status to rejected', callToReject.status == CallState.rejected);
  expect('rejectCall appends session to callHistory', service.callHistory.length == 1);

  // Test Cancel Dialing
  service.reset();
  final callToCancel = await service.startCall(
    callerId: 'pat_04',
    callerName: 'Bệnh nhân 4',
    calleeId: 'doc_04',
    calleeName: 'BS. Mai',
    callType: 'audio',
  );
  service.cancelDialing(callToCancel.callId);
  expect('cancelDialing transitions status to ended', callToCancel.status == CallState.ended);

  // ===========================================================================
  // GROUP 7: Offline Callee Failure & Busy Callee Rejection
  // ===========================================================================
  print('\nGroup 7: Offline Callee & Busy Callee Rejection');
  service.reset();

  // Offline callee test
  final offlineCall = await service.startCall(
    callerId: 'pat_05',
    callerName: 'Bệnh nhân 5',
    calleeId: 'doc_offline',
    calleeName: 'BS. Ngoại Tuyến',
    callType: 'audio',
    isCalleeOnline: false,
  );
  expect('startCall to offline callee immediately transitions to failed',
    offlineCall.status == CallState.failed);
  expect('startCall to offline callee contains expected failure reason',
    offlineCall.failureReason!.contains('Bác sĩ hiện đang ngoại tuyến, không thể thực hiện cuộc gọi audio'));

  // Busy callee test
  final busyCall = await service.startCall(
    callerId: 'pat_06',
    callerName: 'Bệnh nhân 6',
    calleeId: 'doc_busy',
    calleeName: 'BS. Bận',
    callType: 'video',
    isCalleeOnline: true,
    isCalleeBusy: true,
  );
  expect('startCall to busy callee immediately transitions to busy',
    busyCall.status == CallState.busy);
  expect('startCall to busy callee contains expected reason',
    busyCall.failureReason!.contains('Bác sĩ đang bận ca tư vấn khác'));

  // ===========================================================================
  // GROUP 8: Missed Call Timeout & Permission Rejection Handlers
  // ===========================================================================
  print('\nGroup 8: Missed Call Timeout & Permission Handlers');
  service.reset();

  final ringingCall = await service.startCall(
    callerId: 'pat_07',
    callerName: 'Bệnh nhân 7',
    calleeId: 'doc_07',
    calleeName: 'BS. Trực',
    callType: 'audio',
  );
  service.simulateRingingTimeout(ringingCall.callId);
  expect('simulateRingingTimeout transitions status to missed',
    ringingCall.status == CallState.missed);
  expect('simulateRingingTimeout adds missed call to callHistory',
    service.callHistory.contains(ringingCall));

  // OS Permission Denied
  final deniedSession = await service.handlePermissionDenied(
    callType: 'video',
    permissionName: 'Microphone và Camera',
  );
  expect('handlePermissionDenied marks session failed', deniedSession.status == CallState.failed);
  expect('handlePermissionDenied sets informative failure reason',
    deniedSession.failureReason!.contains('Ứng dụng cần quyền Microphone và Camera'));

  // In-call Camera Permission Denied
  service.reset();
  final inCallSession = await service.startCall(
    callerId: 'pat_08',
    callerName: 'Bệnh nhân 8',
    calleeId: 'doc_08',
    calleeName: 'BS. Khoa',
    callType: 'video',
  );
  service.acceptCall(inCallSession.callId);
  service.handleCameraPermissionDenied(inCallSession.callId);
  expect('handleCameraPermissionDenied turns off camera', inCallSession.isCameraEnabled == false);

  // ===========================================================================
  // GROUP 9: Stream Reactivity on Incoming Call Events
  // ===========================================================================
  print('\nGroup 9: Incoming Call Stream Reactivity');
  service.reset();

  CallSessionModel? receivedOnStream;
  final subscription = service.incomingCallStream.listen((session) {
    receivedOnStream = session;
  });

  final streamedCall = await service.startCall(
    callerId: 'pat_stream',
    callerName: 'Bệnh nhân Stream',
    calleeId: 'doc_stream',
    calleeName: 'BS. Stream',
    callType: 'video',
  );

  // Wait a microtask for stream event dispatch
  await Future.delayed(const Duration(milliseconds: 10));

  expect('incomingCallStream emits started call session',
    receivedOnStream != null && receivedOnStream!.callId == streamedCall.callId);
  expect('Emitted session has ringing status',
    receivedOnStream?.status == CallState.ringing);

  await subscription.cancel();

  // ===========================================================================
  // GROUP 10: Call Invariants & State Machine Hardening (Milestone 4 Polish)
  // ===========================================================================
  print('\nGroup 10: Call Invariants & State Machine Hardening');
  service.reset();

  // 10.1: acceptCall on ended session is safely rejected (status remains ended)
  final callEnded = await service.startCall(
    callerId: 'pat_inv_1',
    callerName: 'Bệnh nhân Inv1',
    calleeId: 'doc_inv_1',
    calleeName: 'BS. Inv1',
    callType: 'audio',
  );
  service.acceptCall(callEnded.callId);
  expect('Session connects successfully', callEnded.status == CallState.connected);
  service.endCall(callEnded.callId);
  expect('Session transitions to ended', callEnded.status == CallState.ended);
  // Attempt illegal transition ended -> connected via acceptCall
  service.acceptCall(callEnded.callId);
  expect('acceptCall on ended session is safely rejected (status remains ended)',
    callEnded.status == CallState.ended);

  // 10.2: acceptCall on rejected session is safely rejected (status remains rejected)
  service.reset();
  final callRejected = await service.startCall(
    callerId: 'pat_inv_2',
    callerName: 'Bệnh nhân Inv2',
    calleeId: 'doc_inv_2',
    calleeName: 'BS. Inv2',
    callType: 'video',
  );
  service.rejectCall(callRejected.callId);
  expect('Session transitions to rejected', callRejected.status == CallState.rejected);
  // Attempt illegal transition rejected -> connected via acceptCall
  service.acceptCall(callRejected.callId);
  expect('acceptCall on rejected session is safely rejected (status remains rejected)',
    callRejected.status == CallState.rejected);

  // 10.3: rejectCall on ended session does not mutate status
  service.reset();
  final callEndNoReject = await service.startCall(
    callerId: 'pat_inv_3',
    callerName: 'Bệnh nhân Inv3',
    calleeId: 'doc_inv_3',
    calleeName: 'BS. Inv3',
    callType: 'audio',
  );
  service.acceptCall(callEndNoReject.callId);
  service.endCall(callEndNoReject.callId);
  expect('Call ended before reject attempt', callEndNoReject.status == CallState.ended);
  service.rejectCall(callEndNoReject.callId);
  expect('rejectCall on ended session does not mutate status (remains ended)',
    callEndNoReject.status == CallState.ended);

  // 10.4: Concurrent Call Collision: startCall while another call is connected
  // cleanly ends and archives the prior call into callHistory with areMediaTracksDisposed = true
  service.reset();
  final callFirst = await service.startCall(
    callerId: 'pat_inv_4',
    callerName: 'Bệnh nhân Inv4',
    calleeId: 'doc_inv_4',
    calleeName: 'BS. Inv4',
    callType: 'audio',
  );
  service.acceptCall(callFirst.callId);
  expect('Prior call is connected', callFirst.status == CallState.connected);

  final callSecond = await service.startCall(
    callerId: 'pat_inv_4b',
    callerName: 'Bệnh nhân Inv4b',
    calleeId: 'doc_inv_4b',
    calleeName: 'BS. Inv4b',
    callType: 'video',
  );
  expect('Prior call was cleanly ended on concurrent startCall', callFirst.status == CallState.ended);
  expect('Prior call media tracks are disposed', callFirst.areMediaTracksDisposed == true);
  expect('Prior call is properly archived in callHistory', service.callHistory.contains(callFirst));
  expect('New call session is active and ringing', service.activeSession?.callId == callSecond.callId);
  expect('New call session status is ringing', callSecond.status == CallState.ringing);

  // 10.5: Universal Media Track Disposal across ALL terminal states
  // 10.5.a: rejectCall marks media tracks disposed
  service.reset();
  final cReject = await service.startCall(
    callerId: 'p_dis_1',
    callerName: 'P1',
    calleeId: 'd_dis_1',
    calleeName: 'D1',
    callType: 'audio',
  );
  service.rejectCall(cReject.callId);
  expect('rejectCall sets areMediaTracksDisposed = true', cReject.areMediaTracksDisposed == true);

  // 10.5.b: cancelDialing marks media tracks disposed
  service.reset();
  final cCancel = await service.startCall(
    callerId: 'p_dis_2',
    callerName: 'P2',
    calleeId: 'd_dis_2',
    calleeName: 'D2',
    callType: 'audio',
  );
  service.cancelDialing(cCancel.callId);
  expect('cancelDialing sets areMediaTracksDisposed = true', cCancel.areMediaTracksDisposed == true);

  // 10.5.c: simulateRingingTimeout marks media tracks disposed
  service.reset();
  final cTimeout = await service.startCall(
    callerId: 'p_dis_3',
    callerName: 'P3',
    calleeId: 'd_dis_3',
    calleeName: 'D3',
    callType: 'video',
  );
  service.simulateRingingTimeout(cTimeout.callId);
  expect('simulateRingingTimeout sets areMediaTracksDisposed = true', cTimeout.areMediaTracksDisposed == true);

  // 10.5.d: offline callee failure marks media tracks disposed
  service.reset();
  final cOffline = await service.startCall(
    callerId: 'p_dis_4',
    callerName: 'P4',
    calleeId: 'd_dis_4',
    calleeName: 'D4',
    callType: 'audio',
    isCalleeOnline: false,
  );
  expect('offline callee failure sets areMediaTracksDisposed = true', cOffline.areMediaTracksDisposed == true);

  // 10.5.e: busy callee failure marks media tracks disposed
  service.reset();
  final cBusy = await service.startCall(
    callerId: 'p_dis_5',
    callerName: 'P5',
    calleeId: 'd_dis_5',
    calleeName: 'D5',
    callType: 'video',
    isCalleeBusy: true,
  );
  expect('busy callee failure sets areMediaTracksDisposed = true', cBusy.areMediaTracksDisposed == true);

  // 10.5.f: handlePermissionDenied marks media tracks disposed
  service.reset();
  final cDenied = await service.handlePermissionDenied(
    callType: 'video',
    permissionName: 'Camera',
  );
  expect('handlePermissionDenied sets areMediaTracksDisposed = true', cDenied.areMediaTracksDisposed == true);

  // Final summary
  print('\n======================================================================');
  print('TEST SUMMARY: $passedSpecs / $totalSpecs SPECS PASSED (100% PASS)');
  print('======================================================================\n');
}
