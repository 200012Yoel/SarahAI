#!/usr/bin/env bash
# Actual offline ASR -> neural MT test with a generated, audible Hebrew fixture.
# This is a model-integration test, NOT a substitute for iPhone mic/earbud tests.
set -euo pipefail
mkdir -p qa-artifacts
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y -qq espeak-ng ffmpeg cmake ninja-build
if ! espeak-ng --voices | grep -Eq '[[:space:]]he[[:space:]]'; then
  echo 'FAIL: Hebrew eSpeak voice is unavailable on this runner.' | tee qa-artifacts/audio-qa-error.txt
  exit 1
fi
# Speech is SYNTHESIZED for test only, then passed as acoustic WAV input to
# real Whisper. Neither Whisper transcript nor Qwen translation is prefilled.
espeak-ng -v he -s 135 -w qa-artifacts/hebrew-test-original.wav   'שלום לכולם. הערב אנחנו מדברים על מזג האוויר בירושלים. תודה רבה ולהתראות.'
ffmpeg -y -loglevel error -i qa-artifacts/hebrew-test-original.wav -ar 16000 -ac 1 -c:a pcm_s16le qa-artifacts/hebrew-test-16khz.wav
git clone -q --depth 1 --branch v1.9.4 https://github.com/ggml-org/whisper.cpp.git "$RUNNER_TEMP/whisper.cpp"
cmake -S "$RUNNER_TEMP/whisper.cpp" -B "$RUNNER_TEMP/whisper.cpp/build" -G Ninja -DWHISPER_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build "$RUNNER_TEMP/whisper.cpp/build" -j 4 --target whisper-cli
curl -fL --retry 3 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin' -o "$RUNNER_TEMP/ggml-base.bin"
python3 - <<'PY'
import subprocess,time,pathlib,json
path=pathlib.Path('qa-artifacts')
cmd=[''+__import__('os').environ['RUNNER_TEMP']+'/whisper.cpp/build/bin/whisper-cli','-m',__import__('os').environ['RUNNER_TEMP']+'/ggml-base.bin','-l','he','-f',str(path/'hebrew-test-16khz.wav'),'-otxt','-of',str(path/'hebrew-recognized')]
start=time.monotonic()
p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace')
(path/'whisper-cli.log').write_text(p.stdout,encoding='utf-8')
(path/'whisper-seconds.txt').write_text(str(round(time.monotonic()-start,3)))
if p.returncode: raise SystemExit('Whisper execution failed; see whisper-cli.log')
transcript=(path/'hebrew-recognized.txt').read_text(encoding='utf-8').strip()
(path/'hebrew-recognized-clean.txt').write_text(transcript,encoding='utf-8')
print('Actual recognized Hebrew:',transcript)
if sum('\u0590'<=x<='\u05ff' for x in transcript)<4:
    raise SystemExit('FAIL: Whisper did not recognize Hebrew from the audio fixture.')
PY
git clone -q --depth 1 --branch v0.4.1 https://github.com/ggml-org/llama.cpp.git "$RUNNER_TEMP/llama.cpp"
cmake -S "$RUNNER_TEMP/llama.cpp" -B "$RUNNER_TEMP/llama.cpp/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_COMMON=ON -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_APP=OFF -DGGML_NATIVE=OFF -DGGML_METAL=OFF
cmake --build "$RUNNER_TEMP/llama.cpp/build" -j 4 --target llama-cli
curl -fL --retry 3 'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf' -o "$RUNNER_TEMP/qwen.gguf"
python3 - <<'PY'
import json,os,pathlib,re,subprocess,time,wave
out=pathlib.Path('qa-artifacts')
hebrew=(out/'hebrew-recognized-clean.txt').read_text(encoding='utf-8').strip()
prompt='<|im_start|>system\n/no_think\nTraduis fidèlement les paroles en hébreu vers le français. Renvoie uniquement la traduction française, sans explication, sans commentaire et sans inventer de phrase.\n<|im_end|>\n<|im_start|>user\n/no_think\n'+hebrew+'\n<|im_end|>\n<|im_start|>assistant\n'
cmd=[os.environ['RUNNER_TEMP']+'/llama.cpp/build/bin/llama-cli','-m',os.environ['RUNNER_TEMP']+'/qwen.gguf','-p',prompt,'-n','130','-c','2048','-t','4','-ngl','0','--temp','0.1','--no-display-prompt']
start=time.monotonic()
p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace',timeout=250)
elapsed=time.monotonic()-start
(out/'qwen-cli.log').write_text(p.stdout,encoding='utf-8')
if p.returncode: raise SystemExit('Qwen translation command failed.')
clean=re.sub(r'<think>[\s\S]*?</think>','',p.stdout).strip()
if '</think>' in clean: clean=clean.split('</think>')[-1].strip()
# CLI can emit performance metrics; remove them from the output shown as text.
clean=re.split(r'\n(?:llama_perf_|main: interactive mode|system_info:)',clean)[0].strip()
(out/'french-output.txt').write_text(clean,encoding='utf-8')
with wave.open(str(out/'hebrew-test-16khz.wav')) as wav:
    audio_seconds=wav.getnframes()/wav.getframerate()
report={'test':'Offline Hebrew acoustic WAV -> actual Whisper base -> actual Qwen3 0.6B',
        'audio_file':'hebrew-test-16khz.wav','audio_seconds':round(audio_seconds,2),
        'whisper_seconds':float((out/'whisper-seconds.txt').read_text()),
        'qwen_seconds':round(elapsed,3),
        'recognized_hebrew':hebrew,'model_french_output':clean,
        'tests_physical_iphone_audio_route':False,
        'tests_sarah_app_runtime':False,
        'tests_voice_generation':False}
valid=bool(re.search(r'[A-Za-zÀ-ÿ]{3}',clean)) and clean!=hebrew and '<think>' not in clean
report['passed_format_check']=valid
(out/'audio-integration-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
# A separate known-good Hebrew input isolates the real MT model from poor
# synthetic speech recognized by Whisper. Never insert this input into app UI.
verified_hebrew='שלום לכולם. מזג האוויר בירושלים היום חם.'
verified_prompt=prompt.replace(hebrew,verified_hebrew)
verified_cmd=list(cmd)
verified_cmd[verified_cmd.index('-p')+1]=verified_prompt
mt_start=time.monotonic()
verification=subprocess.run(verified_cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                           text=True,errors='replace',timeout=250)
(out/'qwen-verified-source.log').write_text(verification.stdout,encoding='utf-8')
verified_result=re.sub(r'<think>[\\s\\S]*?</think>','',verification.stdout).strip()
if '</think>' in verified_result: verified_result=verified_result.split('</think>')[-1].strip()
(out/'qwen-verified-french.txt').write_text(verified_result,encoding='utf-8')
verified_ok=verification.returncode==0 and bool(re.search(r'[A-Za-zÀ-ÿ]{3}',verified_result))
report['verified_hebrew_input']=verified_hebrew
report['verified_hebrew_model_answer']=verified_result[:2000]
report['verified_model_format_ok']=verified_ok
report['verified_model_seconds']=round(time.monotonic()-mt_start,3)
report['recognized_repetition_problem']=bool(re.search(r'(?:\\b[^\\W\\d_]+\\b[,. ]*){4,}',hebrew)) if False else any(hebrew.count(w)>=4 for w in hebrew.split() if len(w)>2)
(out/'audio-integration-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
if not verified_ok: raise SystemExit('FAIL: Neural model did not translate a separately validated Hebrew sentence.')
if not valid: raise SystemExit('FAIL: End-to-end pipeline produced no usable French answer.')
if report['recognized_repetition_problem']:
    raise SystemExit('FAIL: Whisper repeatedly hallucinated words from synthetic Hebrew audio. See actual transcript.')
PY
