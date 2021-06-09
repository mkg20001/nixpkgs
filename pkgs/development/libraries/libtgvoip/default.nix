{ stdenv, lib, fetchFromGitHub, pkg-config, autoreconfHook
, openssl, libopus, alsa-lib, libpulseaudio
}:

with lib;

stdenv.mkDerivation rec {
  pname = "libtgvoip";
  version = "unstable-2020-03-02";

  src = fetchFromGitHub {
    owner = "telegramdesktop";
    repo = "libtgvoip";
    rev = "e422d2a80546a32ab7166a9b1058bacfc5daeefc";
    sha256 = "0n6f7215k74039j0zmicjzhj6f45mq6fvkrwzyzibcrv87ib17fc";
  };

  outputs = [ "out" "dev" ];

  nativeBuildInputs = [ pkg-config autoreconfHook ];
  buildInputs = [ openssl libopus alsa-lib libpulseaudio ];
  enableParallelBuilding = true;

  postPatch = ''
    sed "s|#define RTC_DCHECK_IS_ON 1|#define RTC_DCHECK_IS_ON 0|g" -i webrtc_dsp/rtc_base/checks.h
  '';

  meta = {
    description = "VoIP library for Telegram clients";
    license = licenses.unlicense;
    platforms = platforms.linux;
    homepage = "https://github.com/telegramdesktop/libtgvoip";
    maintainers = with maintainers; [ ilya-fedin ];
  };
}
