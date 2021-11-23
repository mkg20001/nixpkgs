with (import ./. {});

callPackage (

{ flutter
, fetchFromGitHub
}:

flutter.mkFlutterApp {
  pname = "firmware-updater";
  version = "unstable";

  # this is broken, you need to run it and put in your own hash here
  vendorHash = "sha256-BS2I9ILEQ5EAzjg/qTE/znIheveI7DnYBUXh6n2mQc8=";

  src = fetchFromGitHub {
    owner = "canonical";
    repo = "ubuntu-desktop-installer";
    rev = "f7340e75518b357a2f7726cfadd62853dd6ff865";
    sha256 = "la+D8ifDQKJFYDuHZas1mjSqaZgz+jqKag7xhDIk2CM=";
    fetchSubmodules = false;
  };

  sourceRoot = "source/packages/ubuntu_desktop_installer";
}

) {}
