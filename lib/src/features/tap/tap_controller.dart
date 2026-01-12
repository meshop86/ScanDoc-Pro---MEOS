import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_tap_repository.dart';
import '../../domain/models.dart';

final tapListProvider = StateNotifierProvider<TapListController, AsyncValue<List<TapHoSo>>>((ref) {
  final repo = ref.watch(driftTapRepositoryProvider);
  return TapListController(repo);
});

class TapListController extends StateNotifier<AsyncValue<List<TapHoSo>>> {
  TapListController(this._repo) : super(const AsyncValue.loading()) {
    _loadTaps();
  }

  final DriftTapRepository _repo;

  Future<void> _loadTaps() async {
    state = const AsyncValue.loading();
    try {
      final taps = await _repo.getAllTapsWithBos();
      state = AsyncValue.data(taps);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<TapHoSo> createTap({required String ownerUserId, String? firstLicensePlate}) async {
    final tap = await _repo.createTap(ownerUserId: ownerUserId, firstLicensePlate: firstLicensePlate);
    await _loadTaps();
    return tap;
  }

  Future<BoHoSo> addBo({required TapHoSo tap, required String licensePlate}) async {
    final bo = await _repo.addBo(tapId: tap.id, licensePlate: licensePlate);
    await _loadTaps();
    return bo;
  }

  Future<void> renameBo({required BoHoSo bo, required String newPlate}) async {
    await _repo.updateBoLicense(bo.id, newPlate);
    await _loadTaps();
  }

  Future<void> renameDoc({required GiayTo doc, required String newName}) async {
    await _repo.renameDoc(doc.id, newName);
    await _loadTaps();
  }

  Future<void> attachDoc({required BoHoSo bo, required GiayTo doc}) async {
    await _repo.upsertDoc(doc);
    await _loadTaps();
  }

  Future<void> markCompleted(TapHoSo tap) async {
    await _repo.markTapCompleted(tap.id);
    await _loadTaps();
  }

  TapHoSo? byId(String id) {
    return state.valueOrNull?.where((t) => t.id == id).firstOrNull;
  }

  BoHoSo? boById(String id) {
    final taps = state.valueOrNull ?? [];
    for (final tap in taps) {
      for (final bo in tap.boList) {
        if (bo.id == id) return bo;
      }
    }
    return null;
  }
}
