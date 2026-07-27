import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/wearable_provider_service.dart';

void main() {
  test('local phone commit runs before optional cloud ingest and watch ACK', () async {
    final order = <String>[];

    final committed = await GarminQueueCommitBarrier.commit(
      commitToPhone: () async => order.add('phone'),
      ingestBackend: () async => order.add('backend'),
      acknowledgeWatch: () async {
        order.add('watch');
        return true;
      },
      removeNativeQueueEntry: () async => order.add('native-queue'),
    );

    expect(committed, isTrue);
    expect(order, ['phone', 'backend', 'watch', 'native-queue']);
  });

  test('local commit failure preserves watch and native queues', () async {
    final order = <String>[];

    await expectLater(
      GarminQueueCommitBarrier.commit(
        commitToPhone: () async {
          order.add('phone');
          throw StateError('disk unavailable');
        },
        ingestBackend: () async => order.add('backend'),
        acknowledgeWatch: () async {
          order.add('watch');
          return true;
        },
        removeNativeQueueEntry: () async => order.add('native-queue'),
      ),
      throwsStateError,
    );

    expect(order, ['phone']);
  });

  test('failed watch delivery preserves the native phone queue', () async {
    final order = <String>[];

    final committed = await GarminQueueCommitBarrier.commit(
      commitToPhone: () async => order.add('phone'),
      ingestBackend: () async => order.add('backend'),
      acknowledgeWatch: () async {
        order.add('watch');
        return false;
      },
      removeNativeQueueEntry: () async => order.add('native-queue'),
    );

    expect(committed, isFalse);
    expect(order, ['phone', 'backend', 'watch']);
  });

  test('cloud ingest failure still ACKs after local phone commit', () async {
    final order = <String>[];

    final committed = await GarminQueueCommitBarrier.commit(
      commitToPhone: () async => order.add('phone'),
      ingestBackend: () async {
        order.add('backend');
        throw StateError('offline');
      },
      acknowledgeWatch: () async {
        order.add('watch');
        return true;
      },
      removeNativeQueueEntry: () async => order.add('native-queue'),
    );

    expect(committed, isTrue);
    expect(order, ['phone', 'backend', 'watch', 'native-queue']);
  });

  test('cloud ingest is optional when omitted', () async {
    final order = <String>[];

    final committed = await GarminQueueCommitBarrier.commit(
      commitToPhone: () async => order.add('phone'),
      acknowledgeWatch: () async {
        order.add('watch');
        return true;
      },
      removeNativeQueueEntry: () async => order.add('native-queue'),
    );

    expect(committed, isTrue);
    expect(order, ['phone', 'watch', 'native-queue']);
  });
}
