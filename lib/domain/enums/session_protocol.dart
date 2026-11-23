/// Timed verbal & visual guidance cue shown during a 2-minute screening recording.
class ProtocolCueStep {
  const ProtocolCueStep({
    required this.atSecond,
    required this.highlightWord,
    required this.instructionTail,
    required this.voicePrompt,
  });

  final int atSecond;
  final String highlightWord;
  final String instructionTail;
  final String voicePrompt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProtocolCueStep &&
        other.atSecond == atSecond &&
        other.highlightWord == highlightWord &&
        other.instructionTail == instructionTail &&
        other.voicePrompt == voicePrompt;
  }

  @override
  int get hashCode => Object.hash(
        atSecond,
        highlightWord,
        instructionTail,
        voicePrompt,
      );
}

/// Three 2-minute video-based gait screening protocols supported by ParkinStep.
enum SessionProtocol {
  turning360(
    storageValue: 'TURNING_360_2MIN',
    shortLabelId: 'Berputar 360°',
    titleId: 'Tes Berputar 360°',
    durationSec: 120,
    cardDescriptionId:
        'Berputar perlahan 360° di tempat selama 2 menit untuk memicu gerak putar.',
    readyInstructionId:
        'Posisikan seluruh tubuh dan kaki di dalam bingkai kamera, lalu tekan Mulai Rekam.',
    spaceChecklistTitleId: 'Ruang Gerak Bebas 1,5 m',
    spaceChecklistDescId:
        'Tersedia area kosong minimal radius 1,5 meter untuk berputar.',
    supportChecklistDescId:
        'Ada penopang kokoh atau pendamping di luar pusat layar.',
    preflightSubtitleId:
        'Pastikan 4 syarat aman berikut sebelum merekam Tes Berputar 360°.',
    preflightVoiceGuideId:
        'Panduan keselamatan sebelum tes berputar 360 derajat. Pertama, pastikan '
        'lantai kering dan bebas kabel. Kedua, sisakan ruang kosong berputar satu '
        'koma lima meter. Ketiga, siapkan kursi kokoh atau pendamping di dekat '
        'Anda. Keempat, pilih alas kaki yang aman dan pastikan pinggul hingga '
        'mata kaki terlihat kamera. Terakhir, pilih status obat ON atau OFF '
        'sebelum menekan Lanjut ke Kamera.',
    timedCues: <ProtocolCueStep>[
      ProtocolCueStep(
        atSecond: 0,
        highlightWord: 'BERPUTAR PERLAHAN',
        instructionTail: '360° di tempat dengan langkah stabil',
        voicePrompt:
            'Mulai berputar perlahan 360 derajat di tempat dengan langkah stabil.',
      ),
      ProtocolCueStep(
        atSecond: 30,
        highlightWord: 'GANTI ARAH',
        instructionTail: 'berputar perlahan ke arah sebaliknya',
        voicePrompt: 'Sekarang ganti arah, berputar perlahan ke arah sebaliknya.',
      ),
      ProtocolCueStep(
        atSecond: 60,
        highlightWord: 'SETENGAH JALAN',
        instructionTail: 'ganti arah lagi dan jaga irama langkah',
        voicePrompt:
            'Sudah satu menit, ganti arah lagi dan jaga irama langkah Anda.',
      ),
      ProtocolCueStep(
        atSecond: 90,
        highlightWord: '30 DETIK TERAKHIR',
        instructionTail: 'ganti arah lagi tetap perlahan dan aman',
        voicePrompt:
            'Tiga puluh detik terakhir, ganti arah lagi secara perlahan.',
      ),
      ProtocolCueStep(
        atSecond: 110,
        highlightWord: '10 DETIK TERAKHIR',
        instructionTail: 'bersiap berhenti menghadap kamera dengan stabil',
        voicePrompt:
            'Sepuluh detik terakhir, bersiap berhenti stabil menghadap kamera.',
      ),
    ],
  ),
  walkBackAndForth(
    storageValue: 'WALK_BACK_AND_FORTH_2MIN',
    shortLabelId: 'Jalan Bolak-Balik',
    titleId: 'Tes Berjalan Bolak-Balik',
    durationSec: 120,
    cardDescriptionId:
        'Berjalan lurus bolak-balik di jalur aman selama 2 menit di depan kamera.',
    readyInstructionId:
        'Pastikan jalur jalan lurus 2-3 meter terlihat jelas di kamera sebelum Mulai Rekam.',
    spaceChecklistTitleId: 'Jalur Lurus Bebas 3 m',
    spaceChecklistDescId:
        'Tersedia jalur lurus kosong 3 meter untuk berjalan bolak-balik tanpa rintangan.',
    supportChecklistDescId:
        'Ada kursi atau pendamping di ujung jalur untuk berpegangan bila perlu.',
    preflightSubtitleId:
        'Pastikan 4 syarat aman berikut sebelum merekam Tes Berjalan Bolak-Balik.',
    preflightVoiceGuideId:
        'Panduan keselamatan sebelum tes berjalan bolak-balik. Pertama, pastikan '
        'lantai kering dan bebas kabel. Kedua, siapkan jalur lurus kosong sekitar '
        'tiga meter. Ketiga, siapkan kursi kokoh atau pendamping di tepi jalur. '
        'Keempat, pakai alas kaki yang aman dan pastikan pinggul hingga mata kaki '
        'terlihat kamera. Terakhir, pilih status obat ON atau OFF sebelum menekan '
        'Lanjut ke Kamera.',
    timedCues: <ProtocolCueStep>[
      ProtocolCueStep(
        atSecond: 0,
        highlightWord: 'JALAN BOLAK-BALIK',
        instructionTail: 'berjalan lurus perlahan lalu putar balik di ujung',
        voicePrompt:
            'Mulai berjalan lurus perlahan lalu putar balik di ujung jalur.',
      ),
      ProtocolCueStep(
        atSecond: 30,
        highlightWord: 'TERUSKAN LANGKAH',
        instructionTail: 'jalan bolak-balik dengan ritme nyaman dan aman',
        voicePrompt:
            'Teruskan berjalan bolak-balik dengan ritme yang nyaman dan aman.',
      ),
      ProtocolCueStep(
        atSecond: 60,
        highlightWord: 'SETENGAH JALAN',
        instructionTail: 'tetap stabil saat berbalik di ujung jalur',
        voicePrompt:
            'Sudah satu menit, tetap jaga keseimbangan saat berbalik arah.',
      ),
      ProtocolCueStep(
        atSecond: 90,
        highlightWord: '30 DETIK TERAKHIR',
        instructionTail: 'lanjutkan berjalan bolak-balik dengan tenang',
        voicePrompt:
            'Tiga puluh detik terakhir, teruskan berjalan bolak-balik perlahan.',
      ),
      ProtocolCueStep(
        atSecond: 110,
        highlightWord: '10 DETIK TERAKHIR',
        instructionTail: 'bersiap berhenti di posisi aman menghadap kamera',
        voicePrompt:
            'Sepuluh detik terakhir, bersiap berhenti di posisi yang aman.',
      ),
    ],
  ),
  sitToStand(
    storageValue: 'SIT_TO_STAND_2MIN',
    shortLabelId: 'Duduk-Berdiri',
    titleId: 'Tes Duduk-Berdiri',
    durationSec: 120,
    cardDescriptionId:
        'Gerakan berdiri tegak dari kursi lalu duduk kembali secara perlahan selama 2 menit.',
    readyInstructionId:
        'Letakkan kursi kokoh terlihat penuh menyamping atau menyerong di kamera, lalu Mulai Rekam.',
    spaceChecklistTitleId: 'Area Kursi Stabil 1,5 m',
    spaceChecklistDescId:
        'Kursi berdiri di lantai rata dan ada ruang aman 1,5 meter di depannya.',
    supportChecklistDescId:
        'Gunakan kursi kokoh tanpa roda dan siapkan pendamping di dekat Anda.',
    preflightSubtitleId:
        'Pastikan 4 syarat aman berikut sebelum merekam Tes Duduk-Berdiri.',
    preflightVoiceGuideId:
        'Panduan keselamatan sebelum tes duduk berdiri. Pertama, pastikan '
        'lantai kering dan tidak licin. Kedua, letakkan kursi kokoh tanpa roda '
        'dengan ruang aman di depannya. Ketiga, pastikan ada pendamping atau '
        'pegangan aman di dekat Anda. Keempat, pastikan pinggul hingga mata kaki '
        'terlihat penuh di kamera. Terakhir, pilih status obat ON atau OFF '
        'sebelum menekan Lanjut ke Kamera.',
    timedCues: <ProtocolCueStep>[
      ProtocolCueStep(
        atSecond: 0,
        highlightWord: 'DUDUK LALU BERDIRI',
        instructionTail: 'berdiri tegak dari kursi lalu duduk kembali perlahan',
        voicePrompt:
            'Mulai gerakan duduk berdiri. Berdiri tegak dari kursi lalu duduk kembali secara perlahan.',
      ),
      ProtocolCueStep(
        atSecond: 30,
        highlightWord: 'JAGA RITME',
        instructionTail: 'berdiri penuh lalu duduk kembali secara terkontrol',
        voicePrompt:
            'Jaga ritme Anda. Berdiri tegak penuh lalu duduk kembali dengan tenang.',
      ),
      ProtocolCueStep(
        atSecond: 60,
        highlightWord: 'SETENGAH JALAN',
        instructionTail: 'lanjutkan perlahan atau jeda duduk bila lelah',
        voicePrompt:
            'Sudah satu menit. Lanjutkan perlahan, atau beristirahat duduk sejenak bila lelah.',
      ),
      ProtocolCueStep(
        atSecond: 90,
        highlightWord: '30 DETIK TERAKHIR',
        instructionTail: 'jaga keseimbangan saat berdiri dan duduk kembali',
        voicePrompt:
            'Tiga puluh detik terakhir, jaga keseimbangan tubuh saat berdiri dan duduk.',
      ),
      ProtocolCueStep(
        atSecond: 110,
        highlightWord: '10 DETIK TERAKHIR',
        instructionTail: 'bersiap mengakhiri tes dalam posisi duduk aman',
        voicePrompt:
            'Sepuluh detik terakhir, bersiap mengakhiri tes dalam posisi duduk yang aman.',
      ),
    ],
  );

  const SessionProtocol({
    required this.storageValue,
    required this.shortLabelId,
    required this.titleId,
    required this.durationSec,
    required this.cardDescriptionId,
    required this.readyInstructionId,
    required this.spaceChecklistTitleId,
    required this.spaceChecklistDescId,
    required this.supportChecklistDescId,
    required this.preflightSubtitleId,
    required this.preflightVoiceGuideId,
    required this.timedCues,
  });

  final String storageValue;
  final String shortLabelId;
  final String titleId;
  final int durationSec;
  final String cardDescriptionId;
  final String readyInstructionId;
  final String spaceChecklistTitleId;
  final String spaceChecklistDescId;
  final String supportChecklistDescId;
  final String preflightSubtitleId;
  final String preflightVoiceGuideId;
  final List<ProtocolCueStep> timedCues;

  ProtocolCueStep cueForElapsed(int elapsedSec) {
    var active = timedCues.first;
    for (final step in timedCues) {
      if (elapsedSec >= step.atSecond) {
        active = step;
      }
    }
    return active;
  }

  ProtocolCueStep? milestoneAt(int elapsedSec) {
    for (final step in timedCues) {
      if (step.atSecond == elapsedSec) {
        return step;
      }
    }
    return null;
  }

  static SessionProtocol fromStorageValue(String? raw) {
    return switch (raw?.toUpperCase()) {
      'WALK_BACK_AND_FORTH_2MIN' || 'FREE_WALK_MONITORING' => walkBackAndForth,
      'SIT_TO_STAND_2MIN' => sitToStand,
      _ => turning360,
    };
  }
}
