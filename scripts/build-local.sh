#!/usr/bin/env bash
# Build CV PDFs locally using the same TeX Live Docker image CI uses.
# Every build runs in one container; aux files go to ./build/ and the final
# PDFs are copied to ./dist/. Needs bash 4+ (associative array), so not the
# macOS system bash 3.2.
#
# Usage: scripts/build-local.sh [all|english|spanish|catalan] [options]
#   --preset NAME         standard (default) | technical | complete | concise
#   --photo-mode MODE     photo (default) | no-photo
#   --style STYLE         awesome (default) | ats (local-only, photo-free)
#   --all-curated         build every public preset x photo-mode asset (24 for all languages)
#   --include-ats         with --all-curated, also build the local-only ATS check
#   --only-preset NAME    with --all-curated, build just this preset
#   --parallelism N       concurrent latexmk runs, 1-16 (default 4)
#
# Examples:
#   scripts/build-local.sh                                         # standard photo CVs in all languages
#   scripts/build-local.sh english --preset technical --photo-mode no-photo
#   scripts/build-local.sh --all-curated --parallelism 4           # 24 public release assets
#   scripts/build-local.sh english --all-curated --include-ats     # CI language build
#   scripts/build-local.sh spanish --all-curated --only-preset complete
#   scripts/build-local.sh catalan --style ats --photo-mode no-photo

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image='texlive/texlive:latest'

# Optional sections as c/e/p/s bits: certifications, extracurricular, projects, skills.
declare -A preset_bits=([standard]=0111 [technical]=0011 [complete]=1111 [concise]=0001)
presets=(standard technical complete concise)

die() { echo "error: $*" >&2; exit 1; }
opt_val() { [[ $# -ge 2 && -n $2 && $2 != -* ]] || die "$1 needs a value"; printf '%s' "$2"; }

target=all preset=standard preset_set=0 photo_mode=photo style=awesome
all_curated=0 include_ats=0 only_preset='' parallelism=4

while (($#)); do
    case $1 in
        all | english | spanish | catalan) target=$1 ;;
        --preset) preset=$(opt_val "$@"); preset_set=1; shift ;;
        --photo-mode) photo_mode=$(opt_val "$@"); shift ;;
        --style) style=$(opt_val "$@"); shift ;;
        --only-preset) only_preset=$(opt_val "$@"); shift ;;
        --parallelism) parallelism=$(opt_val "$@"); shift ;;
        --all-curated) all_curated=1 ;;
        --include-ats) include_ats=1 ;;
        -h | --help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown argument: $1 (see --help)" ;;
    esac
    shift
done

[[ -n $preset && -n ${preset_bits[$preset]:-} ]] || die "unknown preset: $preset"
[[ -z $only_preset || -n ${preset_bits[$only_preset]:-} ]] || die "unknown preset: $only_preset"
[[ $photo_mode == photo || $photo_mode == no-photo ]] || die "unknown photo mode: $photo_mode"
[[ $style == awesome || $style == ats ]] || die "unknown style: $style"
[[ $parallelism =~ ^([1-9]|1[0-6])$ ]] || die "--parallelism must be 1-16"
if ((all_curated)) && [[ $style != awesome ]]; then
    die '--all-curated only builds public Awesome-CV release assets.'
fi
if ((all_curated)) && ((preset_set)); then
    die '--preset cannot be combined with --all-curated; use --only-preset.'
fi
if ((!all_curated)) && [[ -n $only_preset ]]; then
    die '--only-preset requires --all-curated.'
fi
if ((!all_curated)) && ((include_ats)); then
    die '--include-ats requires --all-curated.'
fi
if [[ $style == ats && $photo_mode != no-photo ]]; then
    die 'The ATS style is intentionally photo-free; use --photo-mode no-photo.'
fi

# Each job is four container arguments: source, output stem, section bits, photo flag.
job_args=() stems=()
add_job() { # source stem preset photo-mode
    local photo_flag=0
    [[ $4 == photo ]] && photo_flag=1
    job_args+=("$1" "$2" "${preset_bits[$3]}" "$photo_flag")
    stems+=("$2")
}

if [[ $target == all ]]; then languages=(english spanish catalan); else languages=("$target"); fi
if [[ -n $only_preset ]]; then curated_presets=("$only_preset"); else curated_presets=("${presets[@]}"); fi

for lang in "${languages[@]}"; do
    if ((all_curated)); then
        for p in "${curated_presets[@]}"; do
            for photo in photo no-photo; do
                add_job "cv_$lang" "cv_${lang}_${p}_${photo}" "$p" "$photo"
            done
        done
        if ((include_ats)); then add_job "ats_$lang" "ats_${lang}_standard" standard no-photo; fi
    elif [[ $style == ats ]]; then
        add_job "ats_$lang" "ats_${lang}_${preset}" "$preset" no-photo
    else
        add_job "cv_$lang" "cv_${lang}_${preset}_${photo_mode}" "$preset" "$photo_mode"
    fi
done

# On Linux the container would otherwise leave root-owned files in build/ and dist/
# (so `make clean` fails); HOME must be writable for the font cache.
docker_user=()
if [[ $(uname -s) == Linux ]]; then docker_user=(--user "$(id -u):$(id -g)" -e HOME=/tmp); fi

mkdir -p "$repo_root/build" "$repo_root/dist"
echo "Using image: $image"
echo "Building $((${#job_args[@]} / 4)) variant(s) in one container ($parallelism parallel jobs)."

# One latexmk run per job; -jobname keeps each variant's aux files isolated so they
# can build in parallel. -pretex injects the section toggles ahead of the entry
# point, so no per-variant driver or flags file is needed.
docker run --rm -i ${docker_user[@]+"${docker_user[@]}"} \
    -v "$repo_root:/workdir" -w /workdir "$image" \
    bash -s -- "$parallelism" "${job_args[@]}" <<'CONTAINER'
set -euo pipefail
parallelism=$1
shift

build_variant() {
    src=$1 stem=$2 bits=$3 photo=$4
    echo "=== Building ${stem}.pdf ==="
    latexmk -xelatex -interaction=nonstopmode -halt-on-error \
        -output-directory=build -jobname="${stem}" -usepretex \
        -pretex="\\def\\inccertifications{${bits:0:1}}\\def\\incextracurricular{${bits:1:1}}\\def\\incprojects{${bits:2:1}}\\def\\incskills{${bits:3:1}}\\def\\incphoto{${photo}}" \
        "${src}.tex"
}
export -f build_variant

printf '%s\n' "$@" | xargs -P "${parallelism}" -n 4 bash -c 'build_variant "$@"' _
CONTAINER

for stem in "${stems[@]}"; do
    cp -f "$repo_root/build/$stem.pdf" "$repo_root/dist/"
    echo "  -> $repo_root/dist/$stem.pdf"
    # Keep existing consumers (PersonalPortfolio) on the photo-enabled standard asset.
    if [[ $stem =~ ^(cv_[a-z]+)_standard_photo$ ]]; then
        cp -f "$repo_root/build/$stem.pdf" "$repo_root/dist/${BASH_REMATCH[1]}.pdf"
        echo "  -> $repo_root/dist/${BASH_REMATCH[1]}.pdf (back-compat alias)"
    fi
done
