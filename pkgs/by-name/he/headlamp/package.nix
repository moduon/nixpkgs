{ lib, stdenv, fetchFromGitHub, go, nodejs, yarn, jq,makeWrapper, python3, kubectl, importNpmLock }:

stdenv.mkDerivation rec {
  pname = "headlamp";
  version = "0.31.0";

  src = fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "headlamp";
    tag = "v${version}";
    sha256 = "sha256-F5BLamopq0t7XGeOV8ML135LfRGzxYGFb57pOIvqgg4=";
  };

  nativeBuildInputs = [ go makeWrapper jq];
  buildInputs = [ nodejs yarn python3 kubectl ];

  npmDeps_frontend = importNpmLock {
    inherit version;
    pname = "npm-deps-headlamp-frontend";
    npmRoot = "${src}/frontend";
  };

  # Imitate what `npmConfigHook` does, but without installing (done at buildPhase)
  postPatch = ''
    (
      echo Patching NPM dependencies
      cp -fr --no-preserve=mode $npmDeps_frontend/* frontend/

      # Avoid npm error code EOVERRIDE
      jq 'del(.overrides.typescript)' frontend/package.json > frontend/package.json.tmp
      mv frontend/package.json.tmp frontend/package.json
    )
  '';

  buildPhase = ''
    runHook preBuild

    ${lib.optionalString stdenv.hostPlatform.isLinux "make app-linux"}
    ${lib.optionalString stdenv.hostPlatform.isDarwin "make app-mac"}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    make install

    runHook postInstall
  '';

  fixupPhase = ''
    runHook preFixup
    wrapProgram $out/bin/headlamp \
      --suffix PATH : ${lib.makeBinPath [ kubectl ]}
    runHook postFixup
  '';

  meta = {
    description = "User-friendly Kubernetes UI focused on extensibility";
    homepage = "https://headlamp.dev/";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [yajo];
  };
}
