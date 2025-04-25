{ lib
, stdenvNoCC
, fetchzip
, level-zero
, libgcc
, ocl-icd
, zlib
, autoPatchelfHook
, nix-update-script
, intel-compute-runtime
, makeWrapper
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ollama-ipex-llm";
  version = "2.2.0";

  src = fetchzip {
    url = "https://github.com/intel/ipex-llm/releases/download/v${finalAttrs.version}/ollama-ipex-llm-${finalAttrs.version}-ubuntu.tgz";
    hash = "sha256-9cRsJu2N6WXJy+5PfqyKJ1SX07JumQJsYMPwGYrI4yA=";
  };

  doBuild = false;

  buildInputs = [
    level-zero
    libgcc
    ocl-icd
    zlib
    intel-compute-runtime
  ];

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
    makeWrapper
  ];

  installPhase = ''
    ls -alh $src
    mkdir -p $out/bin $out/lib
    cp $src/ollama-bin $out/bin/ollama
    cp $src/*.so $src/*.so.* $out/lib
    wrapProgram $out/bin/ollama --prefix LD_LIBRARY_PATH : ${intel-compute-runtime.drivers}/lib
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "an LLM acceleration library for Intel GPU (e.g., local PC with iGPU, discrete GPU such as Arc, Flex and Max), NPU and CPU";
    homepage = "https://github.com/intel/ipex-llm";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ ners ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "ollama";
  };
})
